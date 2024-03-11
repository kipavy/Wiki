---
description: >-
  Objectif: Avoir un SSD externe capable de démarrer linux simplement en le
  branchant sur n'importe quel PC.
---

# Linux on Portable SSD

{% hint style="info" %}
Pour que n’importe quel pc puisse détecter le SSD comme bootable, il faut que le SSD comporte une partition esp - efi (500mo fat32), c'est grâce à cette partition que le bios détecte le SSD comme option de démarrage.
{% endhint %}

Au moment de l'écriture de ce tuto, l'installateur Ubuntu comporte un soucis: le disque sélectionné pour l'installation du bootloader (GRUB) n'est actuellement pas celui sur lequel GRUB sera installé, GRUB sera installé sur le premiere partition efi détecté autrement dis dans le cas d'un pc windows, GRUB s'installera sur le pc windows et donc le SSD ne sera pas bootable sur un autre pc, de plus le pc windows ne démarrera plus en débranchant le SSD externe. Pour remédier à cela, dans un live Ubuntu par exemple et avec gparted, enlever les flag boot, esp de tout disque, créer la partition efi sur le SSD externe avec les flags boot, esp. Installer, puis remettre les flags. Comme ça le seul disque qui aura les flags sera le SSD externe

1. Préparer une clé bootable Ubuntu ou autre. Installation de Medicat recommandée sur USB > 64 GB et rapide
2. Boot sur la clé usb, lancer l’installateur linux (safe graphics si ça crash)
3. D’abord entrer en mode try ubuntu pour créer la partition EFI
4. ouvrir gparted, séléctionner le ssd externe, créér partition FAT32 500 MO, puis clic droit, manage flags, boot + esp.
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
