#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi

for tool in parted curl tar grub find findmnt; do
    if ! command -v $tool &> /dev/null
    then
        echo "$tool could not be found"
        exit 1
    fi
done

PARTITION_SYSROOT=`findmnt -n -o SOURCE /`
DISK_BOOT=`echo $PARTITION_SYSROOT | sed 's/[0-9]*$//'`
PARTITION_SYSROOT_NUM=`echo $PARTITION_SYSROOT | grep -o -E '[0-9]+$'`
_DISK_BOOT_CHAR=`echo $DISK_BOOT | grep -o -E '.$'`
_DISK_BOOT_ASCII=`printf %d \'$_DISK_BOOT_CHAR`
DISK_BOOT_INDEX=$((_DISK_BOOT_ASCII-97))


GPT_FLAG=""
if `parted $DISK_BOOT print | grep "Partition Table"  |grep -q gpt`; then
    GPT_FLAG="gpt"
fi

cat << EOF > /etc/grub.d/40_custom
#!/bin/sh
exec tail -n +3 \$0
menuentry "Boot Arch ISO"  \$menuentry_id_option arch_memdisk {
    set root=(hd$DISK_BOOT_INDEX,$GPT_FLAG$PARTITION_SYSROOT_NUM)
    insmod memdisk
    linux16 /memdisk iso
    initrd16 /archlinux-x86_64.iso
}
EOF

sed -i "s/GRUB_DEFAULT=.*/GRUB_DEFAULT=arch_memdisk/g" /etc/default/grub

grub-mkconfig -o /boot/grub/grub.cfg

curl http://mirror.0x.sg/archlinux/iso/2023.07.01/archlinux-x86_64.iso -o /mnt/boot/archlinux-x86_64.iso
curl https://mirrors.edge.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.gz -o /tmp/syslinux-6.03.tar.gz
tar -xzf /tmp/syslinux-6.03.tar.gz -C /tmp
find /tmp/syslinux-6.03 -type f -name memdisk -exec cp {} / \;

sync

reboot now
