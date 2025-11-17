---
description: >-
  How to setup an automated proxmox backup system (host config + LXCs). With
  this you'll be able to get your server up and running in a few minutes from
  scratch.
---

# 💾 Proxmox Backup

We'll need to backup 2 things:

* Proxmox host config (`/etc`)
* LXCs/VMs (using **P**roxmox **B**ackup **S**erver)

## Prerequisites <a href="#post-title-t3_2hnlrt" id="post-title-t3_2hnlrt"></a>

* Having an **external backup location** (backup on same drive is useless), can be a ZFS pool, a network drive (NFS,SMB...), or another physical server but for this tutorial we'll set up PBS inside an LXC and back up on a ZFS "backup" dataset.

{% stepper %}
{% step %}
## Setting up PBS

We'll need PBS to backup both host config and LXCs/VMs.

* Pros: deduplication, incremental (fast, light)
* Cons: adds another LXC that consumes ressources (not much but around 200\~ RAM) but I have a solution for that

### Install PBS

1. Just use this [script](https://community-scripts.github.io/ProxmoxVE/scripts?id=proxmox-backup-server) to add PBS LXC (during installation, select PRIVILEGED LXC, it will be easier)
2. I recommend you then run [PBS Post-Install Script](https://community-scripts.github.io/ProxmoxVE/scripts?id=post-pbs-install) in PBS LXC Console.

### Configuring PBS

ADD BIND MOUNT TO ZFS

* CONFIGURE DATASTORE INSIDE PBS
*   set root password `passwd root`

    login root to ip:8007

    Create new datastore with backing path to our ZFS dataset bind mount

    options > check verify new snapshots
* (optionnal) Create a dedicated backup user on PBS with user permissions: /datastore, role: DatastoreAdmin



{% embed url="https://youtu.be/sOUgzPocqFM?si=DXe0_ZeRhhbFCbAw&t=660" %}

### (Optionnal) Auto PBS start/shutdown

{% hint style="success" %}
PBS doesnt use much resrouces when idle but I just don't like having it always turned on where its only used during backup/prune jobs so I found out a way to have it only turned on when used, you can skip this part if you don't care having PBS always running.
{% endhint %}

#### On PVE:

Starts PBS 1m before scheduled backup job:

```shellscript
59 20 * * * /usr/sbin/pct start 105 >> /var/log/pbs-autostart.log 2>&1
```

#### On PBS LXC:

Shutdown only when no backup/prune tasks are running:

<mark style="color:$danger;">TODO</mark>
{% endstep %}

{% step %}
## Proxmox Host backup

### Automatic (recommended)

replace **--repository** and **PBS\_PASSWORD** according to your PBS config and <mark style="color:$primary;">**execute this once manually just to accept the fingerpint.**</mark>

```shellscript
PBS_PASSWORD='root_password' /usr/bin/proxmox-backup-client backup \
    root.pxar:/etc \
    --repository root@pam@192.168.1.105:backup \
    --backup-id $(hostname)
```

Then, add it to pve crontab, open pve shell > `crontab -e:`

{% code overflow="wrap" %}
```shellscript
59 20 * * * PBS_PASSWORD='root_password' /usr/bin/proxmox-backup-client backup root.pxar:/etc --repository root@pam@192.168.1.105:backup --backup-id $(hostname) >/dev/null 2>&1
```
{% endcode %}

### Manual

For manual `/etc` backup, you can just use this [script](https://community-scripts.github.io/ProxmoxVE/scripts?id=host-backup)
{% endstep %}

{% step %}
## LXCs/VMs Backup w/ PBS

{% embed url="https://www.apalrd.net/posts/2024/pbs_hibernate/" %}

back in PVE, datacenter > storage > add PBS (use the newly created user, copy findergprint from PBS UI (see video)

```shellscript
PBS_LXC_ID="105"
/usr/sbin/pct exec "$PBS_LXC_ID" -- bash -c "proxmox-backup-manager cert info | grep Fingerprint | cut -d ' ' -f 3"
```

create backup job (with PBS as storage)

Creating Backup job in PVE <mark style="color:$danger;">TODO</mark>
{% endstep %}
{% endstepper %}

## Restore method

if the server goes down entirely, we'll need to install a new Proxmox AND create PBS LXC manually again and link the existing datastore... <mark style="color:$danger;">TODO</mark>
