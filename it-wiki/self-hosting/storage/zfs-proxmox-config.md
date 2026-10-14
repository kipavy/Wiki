---
icon: server
---

# ZFS Proxmox Config

{% embed url="https://blog.kye.dev/proxmox-zfs-mounts" %}

1. Create ZFS pool in Proxmox UI : `pve > disks > ZFS > Create ZFS`

### Create ZFS Datasets

Datasets in ZFS allow for organizing and structuring data within ZFS. You can create datasets on a Zpool to organize how and where specific data is stored. A dataset has no fixed size, it can expands to the pool size (or to the quota if set). For example you could have one datasets for your immich and another for your NFS share.

to create 'immich' dataset in 'tank' ZFS pool:

```shellscript
zfs create tank/immich  # zfs create POOL/DATASET
```

### List ZFS pools/datasets

```shellscript
zfs list
```

### Renaming datasets/snapshots

```shellscript
zfs rename pool1/data pool1/archive # Renaming dataset
zfs rename pool1/data@yesterday pool1/data@backup-2025-05-10  # Renaming snapshot
```

### Migrating ZFS

#### Creating snapshot

```shellscript
zfs snapshot -r pool/dataset@migration
```

#### Sending snapshot

```shellscript
zfs send -R pool/dataset@migration | zfs receive -F newpool/dataset
```

{% hint style="info" %}
You can also migrate whole ZFS pool by just not specifying any /dataset. E.g: `zfs snapshot -r pool@migration` ...&#x20;
{% endhint %}

### Access ZFS dataset in LXCs

{% embed url="https://blog.kye.dev/proxmox-zfs-mounts" %}

#### Proxmox setup (done once)

```shellscript
groupadd -g 110000 nas_shares
useradd nas -u 101000 -g 110000 -m -s /bin/bash
chown -R nas:nas_shares /tank/immich/
chown -R nas:nas_shares /tank/other_dataset/
```

#### Bind Mount Dataset to LXC

```shellscript
pct set 105 -mp0 /pool/dataset,mp=/mnt/media_root  # or whatever mount path
```

#### In LXC, adding nas\_shares group

```shellscript
groupadd -g 10000 nas_shares
usermod -aG nas_shares $USER  # or whatever user needs to access data
```

### Add disk to an existing pool

{% hint style="success" %}
Use stable disk identifiers (e.g., `/dev/disk/by-id/...`) for all commands. You can see your disks ids by using `ls -l /dev/disk/by-id/`
{% endhint %}

#### Increase Redundancy: From 1 Disk to a Mirror (RAID 1)

Adds `<new_disk>` to duplicate the data from `<existing_disk>`.

```shellscript
zpool attach <POOL> <EXISTING_DISK_ID> <NEW_DISK_ID>
```

Example:

```shellscript
zpool attach tank /dev/disk/by-id/wwn-0x5000c500c2f8832c /dev/disk/by-id/wwn-0x5000c500c2f8832d
```

#### Increase Capacity: Adding a New VDEV

<table data-header-hidden><thead><tr><th>Configuration of Added VDEV</th><th>Goal</th><th width="293.39990234375">Command</th><th>Result</th></tr></thead><tbody><tr><td>Stripe (RAID 0)</td><td>Add a single disk to increase capacity without redundancy.</td><td><code>zpool add &#x3C;pool_name> &#x3C;disk_1></code></td><td>Danger: Creates a RAID 0 stripe with the rest of the pool. Complete data loss upon any single drive failure.</td></tr><tr><td>New Mirror (RAID 10)</td><td>Add two mirrored disks to increase capacity with redundancy.</td><td><code>zpool add &#x3C;pool_name> mirror &#x3C;disk_1> &#x3C;disk_2></code></td><td>Increases the pool capacity by adding a new mirrored VDEV.</td></tr><tr><td>New RAIDZ-1</td><td>Add three disks with 1 parity disk to increase capacity.</td><td><code>zpool add &#x3C;pool_name> raidz1 &#x3C;d1> &#x3C;d2> &#x3C;d3></code></td><td>Increases pool capacity with a new RAIDZ-1 VDEV.</td></tr><tr><td>New RAIDZ-2</td><td>Add four disks with 2 parity disks to increase capacity.</td><td><code>zpool add &#x3C;pool_name> raidz2 &#x3C;d1> &#x3C;d2> &#x3C;d3> &#x3C;d4></code></td><td>Increases pool capacity with a new RAIDZ-2 VDEV.</td></tr></tbody></table>

#### Expanding an Existing RAIDZ VDEV

`zpool online -e <pool_name> <new_disk>` (after physical addition) OR `zpool expand <pool_name>`

#### Verification after Adding

```shellscript
zpool status <pool_name>
```

### Replacing a failed disk

{% hint style="danger" %}
Always identify disks by `/dev/disk/by-id/...` and cross-check the **serial number**. `/dev/sdX` names are reassigned at boot — acting on a stale `sdb` is how people wipe the healthy disk.
{% endhint %}

Guided script — picks the disks for you from arrow-key menus and asks before every command, so there is no ID to type by hand:

```shellscript
bash <(curl -sL https://raw.githubusercontent.com/kipavy/Wiki/main/scripts/zfs-replace-disk.sh)
```

Add `--dry-run` to see the exact commands without running them. The manual steps below are the same procedure by hand.

#### 1. Identify the disk

```shellscript
zpool status -v tank
```

The failing device is the leaf with a bad `STATE` or non-zero `READ`/`WRITE`/`CKSUM`:

```
	NAME                        STATE     READ WRITE CKSUM
	tank                        DEGRADED     0     0     0
	  mirror-0                  DEGRADED     0     0     0
	    wwn-0x5000c500c2f8832c  ONLINE       0     0     0
	    wwn-0x5000c500c2f8832d  FAULTED      6    98     0  too many errors
```

Get its serial, and **write the serial down before you open the case** — it is the only identifier that survives a reboot and cable reshuffle:

```shellscript
smartctl -i /dev/disk/by-id/wwn-0x5000c500c2f8832d   # Serial Number + model
ls -l /dev/disk/by-id/                              # by-id -> sdX mapping
```

{% hint style="info" %}
If the disk is already gone, `zpool status` shows a bare number (its GUID) instead of a name, with a `was /dev/disk/by-id/...` note. Use that GUID in place of the device name in the commands below — `zpool replace tank 9823741982374198237 /dev/disk/by-id/<new>`.
{% endhint %}

#### 2. Dead or dying?

This decides everything that follows.

<table><thead><tr><th width="190">Symptom</th><th>Path</th><th>Why</th></tr></thead><tbody><tr><td><code>FAULTED</code>, <code>UNAVAIL</code>, <code>REMOVED</code>, or absent</td><td><strong>Dead</strong> — offline, swap, replace</td><td>ZFS already stopped using it; there is nothing left to read from it.</td></tr><tr><td><code>ONLINE</code>/<code>DEGRADED</code> with CKSUM or READ/WRITE errors, or SMART reallocated/pending sectors</td><td><strong>Dying</strong> — hot-replace, leave it online</td><td>It still returns data. Keeping it online lets the resilver read from it <em>and</em> its peer.</td></tr></tbody></table>

Check SMART for the dying case:

```shellscript
smartctl -H -A /dev/disk/by-id/wwn-0x5000c500c2f8832d | grep -E 'result|Reallocated|Pending|Uncorrect'
```

Anything non-zero in `Reallocated_Sector_Ct` (5) or `Current_Pending_Sector` (197) means the drive is failing even if ZFS still calls it `ONLINE`.

#### 3a. Dead path

```shellscript
zpool offline tank /dev/disk/by-id/wwn-0x5000c500c2f8832d
# power down if the bays are not hot-swap, then physically swap the disk
zpool replace tank /dev/disk/by-id/wwn-0x5000c500c2f8832d /dev/disk/by-id/wwn-0x5000c500c2f8839f
```

#### 3b. Dying path

Connect the new disk **alongside** the old one (needs a free SATA port) and replace without offlining anything:

```shellscript
zpool replace tank /dev/disk/by-id/wwn-0x5000c500c2f8832d /dev/disk/by-id/wwn-0x5000c500c2f8839f
```

{% hint style="warning" %}
Do **not** `zpool offline` a disk that still reads. On a 2-disk mirror that leaves you with a single copy of everything for the entire resilver — hours of zero redundancy, exactly when a second disk is most likely to complain.

No free port? Then you have no choice but the dead path. Accept the risk and don't skip the scrub afterwards.
{% endhint %}

#### 4. Watch the resilver

```shellscript
zpool status -v tank
```

```
  scan: resilver in progress since Thu Jul 30 11:02:03 2026
	984G resilvered, 35.42% done, 01:41:12 to go
```

The pool stays online and usable throughout. When the resilver finishes ZFS **automatically detaches the old device** — you never need `zpool detach` here, and running it by hand is a good way to break something.

#### 5. Afterwards

```shellscript
zpool clear tank    # reset stale error counters
zpool scrub tank    # full verify; worth doing monthly anyway
```

If the replacement is bigger and every member of the vdev has now been replaced, claim the extra space:

```shellscript
zpool set autoexpand=on tank
zpool online -e tank /dev/disk/by-id/wwn-0x5000c500c2f8839f
```

Then clear the old disk out of Scrutiny so it stops alerting — see [HDD Monitoring Proxmox](hdd-monitoring-proxmox.md).

#### What the error counters mean

<table><thead><tr><th width="130">Column</th><th>Meaning</th><th>Usual cause</th></tr></thead><tbody><tr><td><code>CKSUM</code></td><td>Data read back did not match its checksum. ZFS repaired it from the mirror.</td><td>Silent corruption: failing media, bad cable, bad RAM.</td></tr><tr><td><code>READ</code>/<code>WRITE</code></td><td>The I/O itself failed.</td><td>Dying drive — or a loose/failing SATA cable. Reseat before condemning the disk.</td></tr></tbody></table>

{% hint style="info" %}
`DEGRADED` means redundancy is reduced, **not** that data is lost. On a 2-disk mirror with one disk gone, all your data is intact on the survivor — but there is no second copy, so replace it promptly and don't start a big rebalance in the meantime.
{% endhint %}

#### If the boot SSD dies instead

That is not a ZFS problem. Proxmox here lives on a single ext4/LVM SSD and no part of it belongs to `tank`, so recovery is: reinstall PVE, `zpool import -f tank` to re-adopt the pool untouched, then restore the guests. Already written up in [#restore-method](proxmox-backup.md#restore-method "mention").

{% hint style="info" %}
**Would two mirrored SSDs (ZFS root) be better?** For uptime, yes: a dead boot SSD becomes a `zpool replace` instead of a reinstall, and you get OS snapshots to roll back a bad upgrade.

But it is not free — ZFS write amplification plus sync-heavy Proxmox writes (`pmxcfs`, `pvestatd`, logs) chew through consumer SSDs that lack power-loss protection, ARC costs RAM, `local-lvm` thin provisioning gives way to zvols, and adopting it means reinstalling Proxmox.

Since guest data already goes to PBS and mirrors to R2, mirroring the root buys **less downtime, not more safety**.
{% endhint %}
