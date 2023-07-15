# VPS to Arch with LUKS&LVM

Install Arch Linux with LUKS over LVM. Boot unlock by SSH.

## How it works

1. Boot to Memdisk, run Arch ISO from RAM.
2. Erase system disk, create Boot & LVM & Swap & Recovery partitions.
3. Create PV, VG, LV
4. Create LUKS over LV, mount to /mnt, format ext4
5. Mount Boot partition to /mnt/boot
6. Install arch to /mnt. Regular setup.
    * my setup: `pacstrap -K /mnt base base-devel linux linux-firmware grub nano man-pages man-db texinfo lvm2 openssh dhcpcd git curl wget net-tools btop`
7. Additionally install `lvm2 cryptsetup openssh mkinitcpio-netconf mkinitcpio-dropbear mkinitcpio-utils`
8. <b>`arch-chroot /mnt`</b>
9. Insert `lvm2 netconf dropbear encryptssh` to HOOKS in `/etc/mkinitcpio.conf`, between `block` and `filesystems`.
   * DO NOT ADD `encrypt` along with `encryptssh`!!! THEY BREAK EACH OTHER!!!
10. `mkinitcpio -p linux`
11. Add public key to `/etc/dropbear/root_key`
12. `grub-install --target=i386-pc /dev/XdY`
13. Edit /etc/default/grub:
    1.  `device_UUID=$(blkid -s UUID -s TYPE -o value | grep crypto_LUKS -B 1 | head -n 1)`
    2.  `GRUB_CMDLINE_LINUX_DEFAULT` append `ip=dhcp cryptdevice=UUID=${DEVICE_UUID}:root root=/dev/mapper/root`
        * ip=dhcp can be replaced with static ip, e.g.
        * ip=192.168.1.1:::::eth0:none
        * ip=192.168.1.1::192.168.1.254:255.255.255.0::eth0:none
    3.  `GRUB_ENABLE_CRYPTODISK=y`
14. `grub-mkconfig -o /boot/grub/grub.cfg` to apply changes.
15. Finish regular arch installation.

## Requirements

- Bootloader is grub2. Disk is MBR/GPT.
- Only BIOS is tested. UEFI is untested.

## Warning

Everything on the VPS will be lost. Make sure you have a backup of your data before you start.

Save backup to your local computer or another VPS.

After Wiping the disk, the VPS will be unbootable until GRUB2 is installed to boot partition.\
DO NOT REBOOT UNLESS YOU KNOW WHAT YOU ARE DOING.

## Something went wrong. How to recover?

Re-install the OS from the VPS provider's control panel. Consider retrying the script.

## How to Use

### Stage 1: Boot to Memdisk, run Arch ISO from RAM

```sh
wget https://raw.githubusercontent.com/DKingAlpha/vps2luks/main/1_bootmemdisk.sh
sudo bash 1_bootmemdisk.sh
```

### Stage 2: In Arch ISO, run the installation script.

```sh
wget https://raw.githubusercontent.com/DKingAlpha/vps2luks/main/2_install_arch.sh
sudo bash 2_install_arch.sh
```
