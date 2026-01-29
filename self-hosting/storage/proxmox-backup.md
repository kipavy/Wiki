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
00 21 * * * PBS_PASSWORD='root_password' /usr/bin/proxmox-backup-client backup root.pxar:/etc --repository root@pam@192.168.1.105:backup --backup-id $(hostname) >/dev/null 2>&1
```
{% endcode %}

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
Since we used PBS on the same server we still need to set up PBS again, which is the only downside I see to this approach. Though this is pretty easy and quick.
{% endhint %}

1. Re-install PVE from ISO
2. Import existing ZFS pool

```shellscript
zpool import -f pool_name
```

3.

{% hint style="warning" %}
Make sure to not use same ID for this temporary PBS LXC otherwise I guess it'll restore itself during backup and crash, don't try this
{% endhint %}

You can restore PBS like this:

```shellscript
pct restore 999 /your_zfs_pool/datastore/ct/ID-LXC/DATE/index.json.fidx --storage local-lvm
```

or you can recreate it and its Datastore manually [#setting-up-pbs](proxmox-backup.md#setting-up-pbs "mention")

4. Restore PBS Backup from PBS GUI













