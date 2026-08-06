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
3. set root password `passwd root`

### Configuring PBS

1. Add bind mount to ZFS in PBS LXC, refer to [#bind-mount-dataset-to-lxc](zfs-proxmox-config.md#bind-mount-dataset-to-lxc "mention"), you don't need to handle the uid/gid part because PBS is Privileged LXC
2. login to PBS ip:8007 (using root and the password you set in the previous step)
3. Create new datastore with "Backing Path" to our ZFS dataset bind mount
4. (optionnal) options > check verify new snapshots
5. (optionnal) Create a dedicated backup user on PBS with user permissions: /datastore, role: DatastoreAdmin

Video tutorial:

{% embed url="https://youtu.be/sOUgzPocqFM?si=DXe0_ZeRhhbFCbAw&t=660" %}

### (Optionnal) Auto PBS start/shutdown

{% hint style="success" %}
PBS doesnt use much resrouces when idle but I just don't like having it always turned on where its only used during backup/prune jobs so I found out a way to have it only turned on when used, you can skip this part if you don't care having PBS always running.
{% endhint %}

#### On PVE:

Starts PBS 1m before scheduled backup job:

<pre class="language-shellscript"><code class="lang-shellscript"><strong>59 20 * * * /usr/sbin/pct start 105 >> /var/log/pbs-autostart.log 2>&#x26;1
</strong></code></pre>

{% hint style="warning" %}
Here I schedule the start at 20h59 because my backup jobs (see: [#proxmox-host-backup](proxmox-backup.md#proxmox-host-backup "mention") and [#lxcs-vms-backup](proxmox-backup.md#lxcs-vms-backup "mention")) are scheduled on 21h00.
{% endhint %}

#### On PBS LXC:

Copy, paste this script in PBS LXC Shell, it will create a systemd service that will automatically shutdown 5m after the last backup/prune jobs:

```shellscript
#!/bin/bash
apt update > /dev/null 2>&1 && apt install -y jq > /dev/null 2>&1

echo \"Création du script de vérification...\"
cat > /usr/local/sbin/pbs-auto-shutdown.sh <<'EOF'
#!/bin/bash
RUNNING_TASKS=$(proxmox-backup-manager task list --output-format json | jq 'length')

if [ "$RUNNING_TASKS" -eq 0 ]; then
    echo "$(date): Aucune tâche PBS. Attente de 2 minutes..."
    sleep 120
    RUNNING_TASKS=$(proxmox-backup-manager task list --output-format json | jq 'length')
    
    if [ "$RUNNING_TASKS" -eq 0 ]; then
        echo "$(date): Extinction sécurisée."
        shutdown now
    else
        echo "$(date): Tâche apparue. Surveillance continue."
    fi
else
    echo "$(date): Tâches en cours détectées ($RUNNING_TASKS). Le LXC reste allumé."
fi
EOF

chmod +x /usr/local/sbin/pbs-auto-shutdown.sh

cat > /etc/systemd/system/pbs-auto-shutdown.service <<EOF
[Unit]
Description=Proxmox Backup Server Auto Shutdown Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/sbin/pbs-auto-shutdown.sh
EOF

cat > /etc/systemd/system/pbs-auto-shutdown.timer <<EOF
[Unit]
Description=Run PBS Auto Shutdown Service every 5 minutes

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
EOF

# Démarrage du service d'arrêt dans le LXC
systemctl daemon-reload
systemctl enable --now pbs-auto-shutdown.timer

echo "✅ Service d'arrêt sécurisé configuré dans le LXC."
```

useful link if your PBS is on another server:

{% embed url="https://www.apalrd.net/posts/2024/pbs_hibernate/" %}
{% endstep %}

{% step %}
## Proxmox Host backup

### Automatic (recommended)

{% hint style="danger" %}
`/etc/pve` is a **FUSE mount** (pmxcfs). `proxmox-backup-client` does **not** descend into it, so a plain `root.pxar:/etc` backup **silently misses your entire cluster config** — `storage.cfg`, `user.cfg`, `jobs.cfg`, all guest configs (`nodes/*/lxc`, `qemu-server`), and `priv/`. During a bare-metal restore that's exactly what you need. **Always back up `/etc/pve` as a second archive** (you'll see `skipping mount point: "pve"` on the first one — that's expected).
{% endhint %}

First, create a dedicated **API token** on PBS so you don't store a root password. On the PBS LXC shell:

```shellscript
proxmox-backup-manager user generate-token proxmox@pbs host-backup
proxmox-backup-manager acl update /datastore/backup DatastoreAdmin --auth-id 'proxmox@pbs!host-backup'
```

On PVE, store the token secret (root-only) and create the backup script `/usr/local/bin/pve-etc-backup.sh`:

```shellscript
echo '<token-secret>' > /root/.pbs-host-token && chmod 600 /root/.pbs-host-token
```

{% code overflow="wrap" %}
```shellscript
#!/bin/bash
set -uo pipefail
PBS_CT=105                                    # your PBS LXC id
export PBS_PASSWORD="$(cat /root/.pbs-host-token)"
export PBS_FINGERPRINT='<pbs-fingerprint>'    # proxmox-backup-manager cert info | grep -i fingerprint
REPO='proxmox@pbs!host-backup@192.168.1.105:backup'

# make sure the PBS LXC is up (needed if you use the auto-shutdown trick above)
if [ "$(pct status $PBS_CT 2>/dev/null)" != "status: running" ]; then
    pct start $PBS_CT || true
    for i in $(seq 1 30); do
        pct exec $PBS_CT -- systemctl is-active proxmox-backup-proxy 2>/dev/null | grep -q '^active' && break
        sleep 2
    done
fi

exec /usr/bin/proxmox-backup-client backup \
    etc.pxar:/etc \
    pve.pxar:/etc/pve \
    --backup-id "$(hostname)" \
    --repository "$REPO"
```
{% endcode %}

```shellscript
chmod 700 /usr/local/bin/pve-etc-backup.sh
/usr/local/bin/pve-etc-backup.sh   # run once to test + accept fingerprint
```

Then add it to the PVE crontab (`crontab -e`), a couple of minutes **before** your guest backup job so PBS is already running:

{% code overflow="wrap" %}
```shellscript
58 20 * * * /usr/local/bin/pve-etc-backup.sh >> /var/log/pve-etc-backup.log 2>&1
```
{% endcode %}

{% hint style="info" %}
The backup group is owned by whoever first created it. If you get `backup owner check failed`, the group belongs to a different user/token — either keep using that same identity, or `proxmox-backup-client snapshot forget` the old group and let the token recreate it.
{% endhint %}

### Manual

For manual `/etc` backup, you can just use this [script](https://community-scripts.github.io/ProxmoxVE/scripts?id=host-backup)
{% endstep %}

{% step %}
## LXCs/VMs Backup

1. back in PVE, datacenter > storage > add PBS (use the newly created user, you can get fingerprint from previous step or by running this command in PBS LXC shell or in just get it in PBS UI (see video).

```shellscript
proxmox-backup-manager cert info | grep Fingerprint | cut -d ' ' -f 3
```

2. create backup job (with PBS as storage)

Video tutorial:

{% embed url="https://youtu.be/sOUgzPocqFM?si=p6gQJ1TtyydbH52W&t=940" %}
{% endstep %}
{% endstepper %}

## Restore method

{% hint style="info" %}
Typical trigger: the **system SSD dies** (I/O errors everywhere, `ls`/`df` return `Input/output error`, `/proc/mounts` shows the root ext4 as `emergency_ro`). Your guests and data live on the **ZFS pool**, which is a separate device — it's safe. You're only rebuilding the OS disk.
{% endhint %}

{% hint style="info" %}
Because PBS runs on the **same** server, you have a chicken-and-egg problem: you can't restore anything until a PBS is serving the datastore. The fix: run a **temporary PBS on the host** to serve the existing datastore, restore everything (including the PBS LXC itself), then remove the temporary PBS.
{% endhint %}

{% hint style="danger" %}
The old `pct restore … index.json.fidx --storage local-lvm` trick **no longer works** on PVE 9 / PBS 4. That index format is gone and `pct restore` treats the path as a vzdump archive (`This does not look like a tar archive`). Use the method below.
{% endhint %}

### 1. Reinstall PVE

Reinstall PVE from ISO onto the (new) system disk. **At the "Target Harddisk" step, select ONLY the system disk** — never a ZFS layout that spans your data-pool disks, or you'll wipe them. Safest: physically unplug the pool disks during install. Then switch to no-subscription repos → [proxmox-post-install.md](proxmox-post-install.md "mention").

### 2. Import your ZFS pool

Reconnect the pool disks (powered off), boot, then:

```shellscript
zpool import -f tank
```

### 3. Run a temporary PBS on the host

The datastore already exists on `tank`; we only need a PBS process to serve it.

{% code overflow="wrap" %}
```shellscript
echo 'deb [signed-by=/usr/share/keyrings/proxmox-archive-keyring.gpg] http://download.proxmox.com/debian/pbs trixie pbs-no-subscription' > /etc/apt/sources.list.d/pbs.list
apt update && apt install -y proxmox-backup-server

chown backup:backup /tank/backup                                        # datastore root must be owned by the 'backup' user
proxmox-backup-manager datastore create backup /tank/backup --reuse-datastore true   # ADOPT it, don't recreate
```
{% endcode %}

### 4. Add it as PVE storage and restore the guests

```shellscript
FP=$(proxmox-backup-manager cert info | grep -i fingerprint | grep -oiE '([0-9a-f]{2}:){31}[0-9a-f]{2}')
pvesm add pbs pbs-local --datastore backup --server 127.0.0.1 \
    --username root@pam --password '<your-root-pw>' --fingerprint "$FP" --content backup

pvesm list pbs-local                                   # find the snapshot dates
pct restore 105 pbs-local:backup/ct/105/<DATE> --storage local-lvm
# repeat for every CT/VM (use qmrestore for VMs)
```

{% hint style="warning" %}
If your new system disk is **smaller** than the old one, `local-lvm` may be too small for big guests — restore those onto the ZFS pool instead: `pct restore 104 pbs-local:backup/ct/104/<DATE> --storage tank`. Data on **bind-mounts** (e.g. `/tank/immich`) is _not_ in the backups; it stays on the pool and is just re-linked when the guest starts.
{% endhint %}

### 5. Hand over to the real PBS LXC, remove the temporary one

{% hint style="danger" %}
Two PBS must **never** serve the same datastore at once. Stop the host PBS **before** starting the PBS LXC.
{% endhint %}

```shellscript
systemctl disable --now proxmox-backup-proxy proxmox-backup
pvesm remove pbs-local
apt purge -y proxmox-backup-server && apt autoremove --purge -y
pct start 105        # the restored PBS LXC takes over
```

Re-add PBS as PVE storage, this time pointing at the LXC (`192.168.1.105`) with an API token — see [#lxcs-vms-backup](proxmox-backup.md#lxcs-vms-backup "mention"). The original `proxmox@pbs` password lived in `/etc/pve/priv` (lost), so just generate a fresh token in the LXC.

### 6. Restore /etc

With PBS back, restore the host config to a **staging dir** and cherry-pick — never blindly overwrite a running `/etc/pve`:

{% code overflow="wrap" %}
```shellscript
proxmox-backup-client restore host/pve/<DATE> pve.pxar /root/pve-old --repository 'proxmox@pbs!host-backup@192.168.1.105:backup'
proxmox-backup-client restore host/pve/<DATE> etc.pxar /root/etc-old --repository 'proxmox@pbs!host-backup@192.168.1.105:backup'
```
{% endcode %}

Guest configs come back automatically with the guest restores in step 4, so from `/etc` you usually only need bits like `user.cfg`, firewall rules, or custom files under `/etc` proper.













