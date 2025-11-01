---
description: This is a tutorial to setup and use an NFS file share on a Proxmox server.
---

# File Sharing

This tutorial only covers NFS but there are other file sharing methods like SSHFS, SMB, FTP.

Personnaly I chose NFS because it was the most performant option (see benchmarks below). Moreover, I use Tailscale for external access, so using SSHFS would have resulted in double encryption. Though SSHFS could be a good choice because it needs no server config, if you're interested in using SSHFS, the server can be any machine that has SSH server (and for windows clients, check out [#sshfs-win-mount-ssh-host-as-network-drive](../windows/useful-tools.md#sshfs-win-mount-ssh-host-as-network-drive "mention")).

## NFS Server

1. Create <mark style="color:yellow;">**Privileged**</mark> Cockpit LXC [https://community-scripts.github.io/ProxmoxVE/scripts?id=cockpit](https://community-scripts.github.io/ProxmoxVE/scripts?id=cockpit)
2. Once you're logged it into Cockpit dashboard ([https://192.168.1.90:9090/file-sharing](https://192.168.1.90:9090/file-sharing)), Create an NFS Share (don't create in on '/')

## NFS Client

### Windows NFS Client

1. Enable NFS Client on your Windows PC:

{% tabs %}
{% tab title="EASY WAY (Recommended)" %}
Open an **Admin** Powershell and paste this in:

```powershell
Write-Host "Enabling NFS client features..."
Enable-WindowsOptionalFeature -Online -FeatureName ServicesForNFS-ClientOnly, ClientForNFS-Infrastructure -NoRestart

$regPath = 'HKLM:\SOFTWARE\Microsoft\ClientForNFS\CurrentVersion\Default'

nfsadmin client stop
Set-ItemProperty -Path $regPath -Name 'AnonymousUID' -Type DWord -Value 0
Set-ItemProperty -Path $regPath -Name 'AnonymousGID' -Type DWord -Value 0
nfsadmin client start
nfsadmin client localhost config fileaccess=755 SecFlavors=+sys -krb5 -krb5i

Write-Host "`nVerifying registry values..."
Get-ItemProperty -Path $regPath | Select-Object AnonymousUid, AnonymousGid

Write-Host "`nNFS client status:"
Get-Service -Name NfsClnt
Write-Host "`n✅ NFS client successfully enabled and configured."

```
{% endtab %}

{% tab title="EASY WAY 2" %}
1. Open Powershell and paste this in:

```powershell
iwr christitus.com/win | iex
```

2. Config > check NFS > Install Features
3. Wait for install to finish, you can see in the CMD when its done
{% endtab %}

{% tab title="WORST WAY" %}
{% hint style="danger" %}
DON'T DO IT, I included it just for reference but I tried it, it was laggy, slow (2x slower than method 1/2)&#x20;
{% endhint %}

choco install nfs-win

```powershell
choco install nfs-win
```

Note that after this, you won't have `mount` command, so you'll use:

```powershell
net use V: \\nfs\192.168.1.90\srv\nfs_share /PERSISTENT:YES
```
{% endtab %}
{% endtabs %}

2. Mount the network drive automatically, press `Win+R` then `shell:startup`
3. Create a `.bat` file with

```powershell
mount -o anon \\192.168.1.90\YOUR\PATH V:
```

4. You can now either reboot or double click the .bat file to mount the NFS Network Drive.

### Linux NFS Client

TODO
