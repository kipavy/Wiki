---
description: Share a ZFS dataset from Proxmox over SMB (Windows/Android) and optionally NFS (Linux), with permissions that just work.
---

# 📁 File Sharing

**Pick the protocol by client, not by benchmark:**

| Client | Protocol | Why |
| --- | --- | --- |
| Windows | **SMB** | Native SMB3 saturates gigabit. The Windows NFS client is NFSv3-only, maps every user to an anonymous UID, and is not faster: copies fail on permissions and leave `file:Zone.Identifier` stub files behind |
| Android | **SMB** | The only thing file managers speak |
| Linux | NFS (optional) | Native and a bit lighter than SMB. Only worth it if a Linux machine actually mounts the share |

NFS benchmarks well against SMB [between Linux machines](https://blog.ja-ke.tech/2019/08/27/nas-performance-sshfs-nfs-smb.html), but behind a mirrored HDD pool (~150 MB/s) or a remote Tailscale link, the disks or the upload are the bottleneck, not the protocol.

{% hint style="danger" %}
Never leave a share as **guest** (no password). Anyone on the LAN (or on the network of whoever hosts your server) can read and write it.
{% endhint %}

***

## Server (Cockpit LXC)

1. Create a <mark style="color:yellow;">**Privileged**</mark> Cockpit LXC (say yes to the 45drives plugins): [https://community-scripts.github.io/ProxmoxVE/scripts?id=cockpit](https://community-scripts.github.io/ProxmoxVE/scripts?id=cockpit)
2. Bind-mount the dataset into it (on the Proxmox host):

```shellscript
pct set 103 -mp0 /tank/nfs_data,mp=/nfs
```

3. In the container, create **one owner** for every file, whatever protocol writes it:

```shellscript
groupadd -g 1000 kipavy
useradd -u 1000 -g 1000 -M -d /nonexistent -s /usr/sbin/nologin kipavy
smbpasswd -a kipavy                       # the SMB password
chown -R kipavy:kipavy /nfs
find /nfs -type d -exec chmod 2775 {} +   # setgid: new files keep the group
find /nfs -type f -exec chmod 0664 {} +
```

{% hint style="warning" %}
The share root must belong to that user too. A root-owned `755` share root lets nobody create files at the top level, the classic "I can read but not write" symptom.
{% endhint %}

### SMB share

Create it in Cockpit > File Sharing, or directly (Cockpit stores shares in the Samba registry):

```shellscript
net conf addshare samba /nfs writeable=y guest_ok=n
net conf setparm samba "valid users" kipavy
net conf setparm samba "force user" kipavy
net conf setparm samba "force group" kipavy
net conf setparm samba "create mask" 0664
net conf setparm samba "directory mask" 2775
net conf setparm samba "vfs objects" streams_xattr   # Windows metadata (Zone.Identifier...) as xattrs
net conf setparm global "map to guest" never
smbcontrol smbd reload-config
net conf list                                        # check
```

### Windows "Previous Versions" (ZFS snapshots)

With [sanoid snapshots](zfs-proxmox-config.md#automatic-snapshots-sanoid) on the dataset, Samba can show them in Windows (right click a file or folder > Properties > **Previous Versions**), so anyone can restore their own files. The bind mount already exposes `/nfs/.zfs/snapshot` in the LXC:

```shellscript
net conf setparm samba "vfs objects" "shadow_copy2 streams_xattr"
net conf setparm samba "shadow:snapdir" ".zfs/snapshot"
net conf setparm samba "shadow:snapprefix" "^autosnap"
net conf setparm samba "shadow:delimiter" "_"
net conf setparm samba "shadow:format" "_%Y-%m-%d_%H:%M:%S"
net conf setparm samba "shadow:sort" "desc"
net conf setparm samba "shadow:localtime" "no"     # sanoid names snapshots in UTC
smbcontrol smbd reload-config
smbclient //localhost/samba -U kipavy -c 'allinfo "some file"'   # lists @GMT-... versions
```

### NFS export (only if a Linux client needs it)

Squash to the same owner and restrict the clients (here: Tailscale devices + the LAN):

```shellscript
echo '/nfs 100.64.0.0/10(rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=1000) 192.168.1.0/24(rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=1000)' \
  > /etc/exports.d/cockpit-file-sharing.exports
exportfs -ra
```

No Linux client? `systemctl disable --now nfs-server` and empty that file.

***

## Clients

### Windows (SMB)

Save the password, then map the drive (persists across reboots, no startup script needed):

```powershell
cmdkey /add:cockpit.lan /user:kipavy /pass:YOUR_PASSWORD
net use N: \\cockpit.lan\samba /persistent:yes
```

`cockpit.lan` is served by AdGuard ([local DNS](proxmox-local-dns.md)), so the drive survives a network move.

If the Windows NFS client was installed before, remove it (admin PowerShell, then reboot):

```powershell
Disable-WindowsOptionalFeature -Online -FeatureName ServicesForNFS-ClientOnly,ClientForNFS-Infrastructure -NoRestart
```

### Android (SMB)

Any file manager with SMB (Material Files, Solid Explorer, CX File Explorer): host `cockpit.lan` (or the IP), share `samba`, user `kipavy` + password.

### Linux

{% tabs %}
{% tab title="SMB" %}
```shellscript
sudo apt install cifs-utils
printf 'username=kipavy\npassword=YOUR_PASSWORD\n' | sudo tee /root/.smb-nas >/dev/null && sudo chmod 600 /root/.smb-nas
sudo mkdir -p /mnt/nas
echo '//cockpit.lan/samba /mnt/nas cifs credentials=/root/.smb-nas,uid=1000,gid=1000,x-systemd.automount,_netdev 0 0' | sudo tee -a /etc/fstab
sudo systemctl daemon-reload && sudo mount -a
```
{% endtab %}

{% tab title="NFS" %}
Install the client (`nfs-common` on Debian/Ubuntu, `nfs-utils` on Arch/Fedora), then:

```shellscript
sudo mkdir -p /mnt/nas
echo 'cockpit.lan:/nfs /mnt/nas nfs defaults,noatime,x-systemd.automount,x-systemd.device-timeout=10 0 0' | sudo tee -a /etc/fstab
sudo systemctl daemon-reload && sudo mount -a
```
{% endtab %}
{% endtabs %}
