---
description: >-
  Goal: Have an external SSD capable of booting Linux simply by plugging it into
  any PC.
---

# Linux on Portable SSD

## Requirements

* USB Drive >= 16 GB
* External Drive (SSD, USB or HDD) >= 32 GB to install Linux on

## Tutorial

{% hint style="info" %}
For any PC to be able to detect the SSD as bootable, the SSD must include an esp - efi partition (500mo fat32), which is how the bios detects the SSD as a boot option.
{% endhint %}

At the time of writing this tutorial, the Ubuntu installer has a problem: the disk selected for installing the bootloader (GRUB) is not currently the one on which GRUB will be installed, GRUB will be installed on the first efi partition detected, in other words, in the case of a Windows PC, GRUB will be installed on the Windows PC and therefore the SSD will not be bootable on another PC, and the Windows PC will no longer boot when the external SSD is unplugged. To remedy this, in a live Ubuntu for example and using gparted, remove the boot and esp flags from any disk, create the efi partition on the external SSD with the boot and esp flags. Install, then reset the flags. This way, the only disk to have the flags will be the external SSD.

1. Prepare a bootable Ubuntu USB or any linux . If you have a fast USB Drive >64 GB, I recommend to install [Medicat](../awesome-tools/medicat.md).
2. Boot on USB (use safe graphics if it crashes)
3. Enter in mode "try ubuntu" to create EFI partition (this step is crucial, it enable the portability of the drive, it allows the drive to have its own boot option so that any PC can detect it)
4. open gparted, select your external drive (NOT LINUX USB), create FAT32 500 MB partition , then right click on it, manage flags, boot + esp.
5. remove boot+esp flags from your PC main OS to ensure grub will install on the external drive and not on your PC (currently ubuntu install has this bug where it always selects the first EFI partition detected to install grub on it).
6. Start linux install, when asked, select custom partitioning
7. Here are the partitions you need to create on your external Drive:
   1. root: ‘/’; ext4; the size you want for the OS eg: 80 GB
   2. ‘swap’; linux-swap; 1GB (ideally use at least 16GB if you have 16GB RAM)

Here is how it should look like:

<figure><img src="../.gitbook/assets/image (3).png" alt=""><figcaption><p>Here I formatted the free space to NTFS to use the free space as an external Drive in any OS</p></figcaption></figure>

9. Continue install normally
10. Once you are in ubuntu, do <mark style="color:red;">`sudo update-grub`</mark> and install gparted to re-enable the EFI flags on your PC's main OS: <mark style="color:red;">`sudo apt install gparted`</mark> re-enable boot + esp flags for the drives that had it before step 5. (basically your boot drives, C: drive on windows)

***

{% hint style="info" %}
if you reinstalled your main OS and your PC won't automatically boot on the SSD when it's 1st in the boot order, follow these quick steps:
{% endhint %}

1. Go in BIOS and manually boot on your external drive (select the OS manager EFI partition, not the USB Drive entry itself)
2.  Follow this screenshot to reorder your boot option to ensure ubuntu is first.

    <figure><img src="../.gitbook/assets/image (1) (1).png" alt=""><figcaption></figcaption></figure>
3. If it still doesn't work, go in BIOS and set low boot priority to USB so it will first boot on grub and not on the default USB boot option that will lead to a boot loop.

***

If you have new chipset error or long boot try these:

1. sudo gedit /etc/default/grub
2. Replace GRUB\_CMDLINE\_LINUX\_DEFAULT="quiet splash" with GRUB\_CMDLINE\_LINUX\_DEFAULT="quiet splash nomodeset nouveau.modeset=0"
3. save & exit
4. sudo update-grub

If you just have a long boot try to disable secure boot in bios.

