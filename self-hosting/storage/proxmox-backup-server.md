# 💾 Proxmox Backup Server

* Idea: Back up everything needed to get our server up and running in a few minutes from scratch: we need to backup 2 things: proxmox host config (/etc: [https://community-scripts.github.io/ProxmoxVE/scripts?id=host-backup](https://community-scripts.github.io/ProxmoxVE/scripts?id=host-backup)) and LXCs (we'll use PBS for that ->)

NEED TO STORE AN EXTERNAL LOCATION (or its useless), can be a ZFS pool, a network drive (NFS,SMB...), or another physical server but for this tutorial we'll set up PBS inside an LXC and back up on a ZFS "backup" dataset

{% embed url="https://www.youtube.com/watch?v=sOUgzPocqFM" %}

{% embed url="https://www.apalrd.net/posts/2024/pbs_hibernate/" %}

* Pros: deduplication, incremental (fast, light)
* Cons: adds another LXC that consumes ressources (not much but around 200\~ RAM) but I have a solution for that



{% stepper %}
{% step %}
### Setting up auto backup of /etc

### TODO

bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/pve/host-backup.sh)"&#x20;

{% code overflow="wrap" %}
```bash
PBS_LXC_ID="105"

/usr/sbin/pct exec "$PBS_LXC_ID" -- bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/pve/post-pbs-install.sh)"
```
{% endcode %}
{% endstep %}

{% step %}
### Creating PBS LXC

PRIVILEGED https://community-scripts.github.io/ProxmoxVE/scripts?id=proxmox-backup-server

INSIDE PBS LXC: https://community-scripts.github.io/ProxmoxVE/scripts?id=post-pbs-install
{% endstep %}

{% step %}
### Configuring PBS

{% embed url="https://youtu.be/sOUgzPocqFM?si=DXe0_ZeRhhbFCbAw&t=660" %}

set root password `passwd root`

login root to ip:8007

Create new datastore with backing path to our ZFS dataset bind mount

options > check verify new snapshots

create user account on PBS with user permissions: /datastore, role: DatastoreAdmin

back in PVE, datacenter > storage > add PBS (use the newly created user, copy findergprint from PBS UI (see video)

create backup job (with PBS as storage)
{% endstep %}

{% step %}
(Optionnal) Auto Shutdown

to save ressources I figured out a way to have PBS only ON when backupping and OFF the rest of the time:

...

(on proxmox host: cronjob at specified backup hour to start LXC)

(in PBS LXC, Service to shutdown when no backup tasks are running)
{% endstep %}
{% endstepper %}
