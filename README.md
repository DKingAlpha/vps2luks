# VPS to Arch with LUKS&LVM

Install Arch Linux with LUKS over LVM on your VPS.

Remote boot-time disk decryption via SSH.

## How to Use

### Stage 1: Boot to Memdisk, run Arch ISO from RAM

```sh
curl https://raw.githubusercontent.com/DKingAlpha/vps2luks/main/1_bootmemdisk.sh -o 1_bootmemdisk.sh
sudo bash 1_bootmemdisk.sh
```

### Stage 2: In Arch ISO, run the installation script.

```sh
curl https://raw.githubusercontent.com/DKingAlpha/vps2luks/main/2_install_arch.sh -o 2_install_arch.sh
curl https://somewhere.com/your_public_key.pub -o your_public_key.pub
sudo bash 2_install_arch.sh /dev/vda  <LUKS_PASSWORD> <SSH_PUBLIC_KEY_FILE>
```

## Requirements

- 2GB RAM minimum.
- Bootloader is grub2. Disk is MBR/GPT.
- Only BIOS is tested. UEFI is untested.

*Tested on Ubuntu 22.04. Other distribution may also work*

## How it works (Codeless Version)
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
