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

1. Prepare a bootable Ubuntu USB or any linux . If you have a fast USB Drive >64 GB, I recommend to install [Medicat](../todo/medicat.md).
2. Boot on USB (use safe graphics if it crashes)
3. Enter in mode "try ubuntu" to create EFI partition (this step is crucial, it enable the portability of the drive, it allows the drive to have its own boot option so that any PC can detect it)
4. open gparted, select your external drive (NOT LINUX USB), créér partition FAT32 500 MO, puis clic droit, manage flags, boot + esp.
5. enlever les flags boot et esp du disque de l’OS principal pour être certain que grub sera sur le ssd externe
6. Lancer l’installation et au moment des partition choisir personnalisé
7. Créer 1 partition ‘/’ ext4 de la taille souhaitée ex: 80 GO Créer 1 partition ‘swap’ de 1g GO (même si il en faudrait une de 16 si vous avez 16GO RAM)
8. Une fois que vous avez sur le SSD externe: 1 partition EFI, 1 Partition ‘/’ et 1 partition ‘swap’

<figure><img src="../.gitbook/assets/image.png" alt=""><figcaption><p>Ici J’ai formaté le reste de l’espace libre en NTFS pour pouvoir l’utiliser dans windows</p></figcaption></figure>

9. Lancer l’installation normalement
10. Une fois dans Ubuntu, faire `sudo update-grub` et dans gparted (`sudo apt install gparted`) Remettre les flags boot, esp pour les disques qui l’avaient avant opération (en gros les disque de démarrage)
11. SI CA MARCHE PLUS APRES REINSTALLATION WINDOWS:
    1. Boot manuellement sur ubuntu depuis le bios
    2.

        <figure><img src="../.gitbook/assets/image (1).png" alt=""><figcaption></figcaption></figure>
    3. remettre USB après windows dans le BIOS
