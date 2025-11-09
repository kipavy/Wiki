# 💾 ZFS Proxmox Config

{% embed url="https://blog.kye.dev/proxmox-zfs-mounts" %}

1. Create ZFS pool in Proxmox UI : `pve > disks > ZFS > Create ZFS`

### Create ZFS Datasets

Datasets in ZFS allow for organizing and structuring data within ZFS. You can create datasets on a Zpool to organize how and where specific data is stored. A dataset has no fixed size, it can expands to the pool size (or to the quota if set). For example you could have one datasets for your immich and another for your NFS share.

to create 'immich' dataset in 'tank' ZFS pool:

```bash
zfs create tank/immich  # zfs create POOL/DATASET
```

### List ZFS pools/datasets

```bash
zfs list
```

### Access ZFS dataset in LXCs

{% embed url="https://blog.kye.dev/proxmox-zfs-mounts" %}

#### Proxmox setup (done once)

```bash
groupadd -g 110000 nas_shares
useradd nas -u 101000 -g 110000 -m -s /bin/bash
chown -R nas:nas_shares /tank/immich/
chown -R nas:nas_shares /tank/other_dataset/
```

#### Bind Mount Dataset to LXC

```bash
pct set 105 -mp0 /pool/dataset,mp=/mnt/media_root  # or whatever mount path
```

#### In LXC, adding nas\_shares group

```bash
groupadd -g 10000 nas_shares
usermod -aG nas_shares $USER  # or whatever user needs to access data
```

### Add disk to an existing pool

{% hint style="success" %}
Use stable disk identifiers (e.g., `/dev/disk/by-id/...`) for all commands. You can see your disks ids by using `ls -l /dev/disk/by-id/`
{% endhint %}

#### Increase Redundancy: From 1 Disk to a Mirror (RAID 1)

Adds `<new_disk>` to duplicate the data from `<existing_disk>`.

```bash
zpool attach <POOL> <EXISTING_DISK_ID> <NEW_DISK_ID>
```

Example:

```bash
zpool attach rpool /dev/disk/by-id/wwn-0x5000c500c2f8832c /dev/disk/by-id/wwn-0x5000c500c2f8832d
```

#### Increase Capacity: Adding a New VDEV

<table data-header-hidden><thead><tr><th>Configuration of Added VDEV</th><th>Goal</th><th width="293.39990234375">Command</th><th>Result</th></tr></thead><tbody><tr><td>Stripe (RAID 0)</td><td>Add a single disk to increase capacity without redundancy.</td><td><code>zpool add &#x3C;pool_name> &#x3C;disk_1></code></td><td>Danger: Creates a RAID 0 stripe with the rest of the pool. Complete data loss upon any single drive failure.</td></tr><tr><td>New Mirror (RAID 10)</td><td>Add two mirrored disks to increase capacity with redundancy.</td><td><code>zpool add &#x3C;pool_name> mirror &#x3C;disk_1> &#x3C;disk_2></code></td><td>Increases the pool capacity by adding a new mirrored VDEV.</td></tr><tr><td>New RAIDZ-1</td><td>Add three disks with 1 parity disk to increase capacity.</td><td><code>zpool add &#x3C;pool_name> raidz1 &#x3C;d1> &#x3C;d2> &#x3C;d3></code></td><td>Increases pool capacity with a new RAIDZ-1 VDEV.</td></tr><tr><td>New RAIDZ-2</td><td>Add four disks with 2 parity disks to increase capacity.</td><td><code>zpool add &#x3C;pool_name> raidz2 &#x3C;d1> &#x3C;d2> &#x3C;d3> &#x3C;d4></code></td><td>Increases pool capacity with a new RAIDZ-2 VDEV.</td></tr></tbody></table>

#### Expanding an Existing RAIDZ VDEV

`zpool online -e <pool_name> <new_disk>` (after physical addition) OR `zpool expand <pool_name>`

#### Verification after Adding

```bash
zpool status <pool_name>
```
