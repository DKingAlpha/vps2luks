# VPS to Arch with LUKS&LVM

Install Arch Linux with LUKS over LVM on your VPS.

Decrypt remotely with SSH key.

This improves security and privacy of your VPS.

## How to Use

### Stage 1: Boot to Memdisk, run Arch ISO from RAM

```sh
curl -L https://github.com/DKingAlpha/vps2luks/raw/main/1_bootmemdisk.sh -o 1_bootmemdisk.sh
sudo bash 1_bootmemdisk.sh
```

### Stage 2: In Arch ISO, run the installation script.

System is accessable from VPS Control Panel -> Console View

```sh
curl -L https://github.com/DKingAlpha/vps2luks/raw/main/2_install_arch.sh -o 2_install_arch.sh
curl -L https://somewhere.com/your_public_key.pub -o your_public_key.pub
sudo bash 2_install_arch.sh <DISK_TO_INSTALL_ARCH>  <SSH_PUBLIC_KEY_FILE>  <LUKS_PASSWORD>

## example
# sudo bash 2_install_arch.sh /dev/vda  your_public_key.pub  my_luks_password
```

In this process you will be prompted to set root password.

### Post Installation

When you see message below, Arch Linux has been installed successfully.

```
Arch Linux Installed. You can take over now and continue post installation
****    LUKS PASSPHRASE IS XXXXXXXXXXXXXXX    ****
#### HERE ARE SOME USEFUL SETUP COMMANDS FOR ARCH LINUX ####
############################################################
arch-chroot /mnt
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
hwclock --systohc
nano /etc/locale.gen
locale-gen
echo "LANG=zh_CN.UTF-8"  > /etc/locale.conf
nano /etc/hostname
############################################################
```

#### Partition Layout
| partition | size | note |
| - | - | - |
| BIOS boot | 2MB | only exists under GPT |
| Boot | 2GB | |
| Swap | MemSize*2 |
| LVM system | Rest of disk |

## Requirements

**Feedback of compatibility is welcome.**

- 2GB RAM minimum.
- Bootloader is grub2. Disk is MBR/GPT.
- Only tested on BIOS. UEFI need feedback.

*1GB RAM may work but not tested, as the Arch ISO requires 512MB RAM while Memdisk used >600MB RAM.*

*Tested on Ubuntu 22.04. Other distribution may also work*

## How it works
1. Download Arch ISO and memdisk to boot partition, boot to Memdisk, run Arch ISO from RAM.
2. Delete all partitions, create Boot & Swap & LVM partitions. Boot partition minimum 2GB
3. In the first place. Install GRUB2 to boot partition. Then download memdisk and arch ISO again. So we have a full functional rescue system now.
4. Make PV, VG, LV with LVM partition.
5. Setup LUKS over LVM.
6. Install Arch to decrypted LUKS filesystem. Setup SSH decryption.
7. Update GRUB2 and initramfs for LUKS and SSH decryption.
8. Reboot to New Arch System.

## Warning

Everything on the VPS will be lost. Make sure you have a backup of your data before you start.

Save backup to your local computer or another VPS.

After Wiping the disk, the VPS will be unbootable until GRUB2 is installed to boot partition.\
DO NOT REBOOT UNLESS YOU KNOW WHAT YOU ARE DOING.

## Something went wrong. How to recover?

1. Quick fix: Reboot to memdisk with files in boot partition.

2. Backup plan: Re-install the OS from the VPS provider's control panel. Consider retrying the script.
