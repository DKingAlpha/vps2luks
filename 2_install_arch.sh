#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi

# we are in arch iso. skip checking tools.

INSTALL_DISK=$1
LUKS_PASSWORD=$2
LUKS_SSH_PUBKEY_FILE=$3

if [ $# -eq 3 ]; then
    echo "Usage: $0 DEVICE_TO_INSTALL LUKS_PASSWORD  LUKS_SSH_PUBKEY_FILE"
    echo ""
    echo "\tLUKS_PASSWORD: string to unlock LUKS partition"
    echo "\tLUKS_SSH_PUBKEY_FILE: SSH public key file to unlock LUKS partition via SSH."
    echo "\t\tLogin as root with private key to unlock."
    exit 1
fi

if [ ! -f "$LUKS_SSH_PUBKEY_FILE" ]; then
    echo "SSH public key file $LUKS_SSH_PUBKEY_FILE not found"
    exit 1
fi

if [ -f "$INSTALL_DISK" ]; then
    INSTALL_DISK=`realpath $INSTALL_DISK`
fi

if [ ! -b "$INSTALL_DISK" ]; then
    echo "Device $INSTALL_DISK not found"
    exit 1
fi

if echo "$INSTALL_DISK"  | grep -qE '[0-9]$'; then
    echo "$INSTALL_DISK is a partition, not a disk"
    exit 1
fi

# if mounted
if grep -q $INSTALL_DISK /proc/mounts; then
    echo "$INSTALL_DISK is mounted. Umount it then retry"
    exit 1
fi

if grep -q /mnt /proc/mounts; then
    echo "/mnt is mounted. Umount it then retry"
    exit 1
fi


while true; do
    read -p "Erase $INSTALL_DISK? [YES|NO]: " yn
    case $yn in
        YES* ) break;;
        * ) echo "Canceled"; exit 0;;
    esac
done

IS_GPT=false
if `parted $DISK_BOOT print | grep "Partition Table"  |grep -q gpt`; then
    IS_GPT=true
fi


for part_num in `ls $INSTALL_DISK* | grep -oE '[0-9]+$' | sort -nr`
do
    echo Deleting $INSTALL_DISK$part_num
    parted $INSTALL_DISK rm $part_num
done

######## DISK REPARTITION ########

######## Partition Layout ########
# BIOS boot partition: keep
# boot partition: 2G
# swap partition: 2 * mem
# system partition: rest
##################################

# size in GiB

MEM_SIZE=`free -g | grep Mem | awk '{print $2}'`
((MEM_SIZE_IN_GB_CEIL=2*(MEM_SIZE+2-1)/2))


# bios boot part + /boot part = 2G
BIOS_BOOT_END=2MiB
# 2G for easier recovery - we can put ISO here
BOOT_PARTITION_SIZE=2
# swap = 2 * mem
SWAP_PARTITION_SIZE=$((MEM_SIZE_IN_GB_CEIL*2))

PART_BASE=0
if $IS_GPT; then
    PART_BASE=1
    parted -s $INSTALL_DISK mkpart "bios" 1MiB $BIOS_BOOT_END set 1 bios_grub on
fi

# setting name in mkpart command is unsupported in ubuntu built-in parted.

parted -s $INSTALL_DISK mkpart primary ext4 \
    $BIOS_BOOT_END ${BOOT_PARTITION_SIZE}GiB \
    name $((PART_BASE+1)) boot \
    set $((PART_BASE+1)) boot on

parted -s $INSTALL_DISK mkpart extended linux-swap \
    ${BOOT_PARTITION_SIZE}GiB $((BOOT_PARTITION_SIZE+SWAP_PARTITION_SIZE))GiB \
    set $((PART_BASE+2)) swap on \
    name $((PART_BASE+2)) swap

parted $INSTALL_DISK mkpart primary \
    $((BOOT_PARTITION_SIZE+SWAP_PARTITION_SIZE))GiB 100% \
    name $((PART_BASE+3)) system \
    set $((PART_BASE+3)) lvm on


######## Variable ########
DEV_BOOT=${INSTALL_DISK}$((PART_BASE+1))
DEV_SWAP=${INSTALL_DISK}$((PART_BASE+2))
DEV_SYSTEM=${INSTALL_DISK}$((PART_BASE+3))

mkswap -f $DEV_SWAP
swapon $DEV_SWAP
######## Install Grub ########

mkfs.ext4 -F $DEV_BOOT

mkdir -p /mnt_boot
mount $DEV_BOOT /mnt_boot
rm -rf /mnt_boot/lost+found
grub-install --target=i386-pc --boot-directory=/mnt_boot $INSTALL_DISK

curl http://mirror.0x.sg/archlinux/iso/2023.07.01/archlinux-x86_64.iso -o /mnt_boot/archlinux-x86_64.iso
curl https://mirrors.edge.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.gz -o /tmp/syslinux-6.03.tar.gz
tar -xzf /tmp/syslinux-6.03.tar.gz -C /tmp
find /tmp/syslinux-6.03 -type f -name memdisk -exec cp {} /mnt_boot/ \;

######## Setup LVM ########
VG_NAME=VG0
LV_NAME_ROOT=lv_root
KEYFILE=/tmp/luks_password

pvcreate $DEV_SYSTEM
vgcreate $VG_NAME $DEV_SYSTEM
lvcreate -l 100%FREE -n $LV_NAME_ROOT $VG_NAME

echo $LUKS_PASSWORD > $KEYFILE

cryptsetup -q luksFormat /dev/$VG_NAME/$LV_NAME_ROOT $KEYFILE
cryptsetup -q -d $KEYFILE open /dev/$VG_NAME/$LV_NAME_ROOT root
rm $KEYFILE

_DEV_DECRYPTED_ROOT=/dev/mapper/root
mkfs.ext4 -F $_DEV_DECRYPTED_ROOT

umount /mnt_boot
rmdir /mnt_boot
mount $_DEV_DECRYPTED_ROOT /mnt
mkdir -p /mnt/boot
mount $DEV_BOOT /mnt/boot

######## Install Arch ########

pacstrap -K /mnt base base-devel linux linux-firmware grub-bios nano man-pages man-db texinfo lvm2 openssh dhcpcd git curl wget net-tools btop  mkinitcpio-netconf mkinitcpio-dropbear mkinitcpio-utils
genfstab -U /mnt >> /mnt/etc/fstab

######## Setup initramfs and GRUB2 for lvm & luks & ssh ########

while true; do
if grep -q "lvm2 netconf dropbear encryptssh" /mnt/etc/mkinitcpio.conf; then
    echo "mkinitcpio.conf already patched"
    break
else
    if grep -q "consolefont block filesystems" /mnt/etc/mkinitcpio.conf; then
        sed -i 's/consolefont block filesystems/consolefont block lvm2 netconf dropbear encryptssh filesystems/g' /mnt/etc/mkinitcpio.conf
        echo "mkinitcpio.conf patched"
        break
    else
        echo "Failed to patch /mnt/etc/mkinitcpio.conf."
        echo 'Please manually insert "lvm2 netconf dropbear encryptssh" before filesystems HOOKS'
        read -p "Press enter to continue"
    fi
fi
done

arch-chroot /mnt mkinitcpio -p linux

cp $LUKS_SSH_PUBKEY_FILE  /mnt/etc/dropbear/root_key

LUKS_DEVICE_UUID=$(blkid -s UUID -s TYPE -o value | grep crypto_LUKS -B 1 | head -n 1)
sed -i 's/#GRUB_ENABLE_CRYPTODISK.*/GRUB_ENABLE_CRYPTODISK=y/g' /mnt/etc/default/grub
if grep -q 'cryptdevice=' /mnt/etc/default/grub; then
    echo "cryptdevice already patched"
else
    sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"ip=dhcp netconf_timeout=180 cryptdevice=UUID=$LUKS_DEVICE_UUID:root root=\/dev\/mapper\/root/g" /mnt/etc/default/grub
    echo "cryptdevice patched"
fi

# In case your network is not DHCP:
# **ip=dhcp** can be replaced with static ip, e.g.
# **ip=192.168.1.1:::::eth0:none**
# **ip=192.168.1.1::192.168.1.254:255.255.255.0::eth0:none**

arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

sync

######## Hand over to user ########

echo "Arch Linux Installed. You can take over now and continue post installation"

echo "#### HERE ARE SOME USEFUL SETUP COMMANDS FOR ARCH LINUX ####"
echo "############################################################"
echo ln -sf  /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo hwclock --systohc
echo nano /etc/locale.gen
echo locale-gen
echo 'echo "LANG=zh_CN.UTF-8"  > /etc/locale.conf'
echo nano /etc/hostname
echo "############################################################"
