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

{% hint style="danger" %}
**If you'd rather use a vzdump job's "Hook Script" field** (Datacenter > Backup > job > Advanced) instead of a fixed-time cron, don't guess the phase name. Per-guest hookscripts (`pct`/`qm set -hookscript`) use `pre-start`/`post-start`/`pre-stop`/`post-stop`, so `pre-backup` *looks* like the right phase for a backup job hook — **it doesn't exist for job-level hookscripts and will silently never fire.** The real phases (see `PVE::VZDump::run_hook_script` in `/usr/share/perl5/PVE/VZDump.pm`) are `job-init`, `job-start`, `job-end`, `job-abort`, `backup-start`, `backup-end`, `backup-abort`, `log-end`, `pre-stop`, `post-stop`, `pre-restart`, `post-restart`. Storage activation happens right after `job-init`, so **`job-init` is the only phase that reliably starts PBS in time**:

```shellscript
#!/bin/bash
if [ "$1" == "job-init" ]; then
    /usr/sbin/pct start 105 2>/dev/null || true
    for i in $(seq 1 30); do
        pct exec 105 -- systemctl is-active proxmox-backup-proxy 2>/dev/null | grep -q '^active' && break
        sleep 2
    done
fi
exit 0
```

Register it on the job: `/etc/pve/jobs.cfg` → add `script /path/to/this-script.sh` under the `vzdump:` block (or set it from the job's Advanced tab in the UI). A hook script silently doing nothing produces no error of its own — the failure only shows up later as `could not activate storage 'pbs-backup': ... No route to host`, which is easy to misread as a networking problem.
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
export PATH="/usr/sbin:/usr/bin:/sbin:/bin:$PATH"    # cron's default PATH lacks /usr/sbin, see hint below
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

{% hint style="danger" %}
**Cron runs scripts with a minimal `PATH`** (typically just `/usr/bin:/bin`), which does **not** include `/usr/sbin` — where `pct`, `pvesm`, and most Proxmox binaries live. Without the explicit `export PATH=...` above (or full paths like `/usr/sbin/pct`), every `pct` call in a cron script silently fails with `pct: command not found`. Because the script has `set -uo pipefail` but not `-e`, and `pct start ... || true` swallows the failure, **the script keeps running and fails much later** with a confusing PBS connection error, while the real cause (`command not found`) is buried a dozen lines up in the log. Test the script by running it directly first — that inherits your interactive shell's full `PATH` and will hide this bug — then verify it also works when invoked exactly as cron would (`env -i PATH=/usr/bin:/bin /usr/local/bin/pve-etc-backup.sh`).
{% endhint %}

```shellscript
chmod 700 /usr/local/bin/pve-etc-backup.sh
/usr/local/bin/pve-etc-backup.sh   # run once to test + accept fingerprint
```

Then schedule it a couple of minutes **before** your guest backup job so PBS is already running. Put it in `/etc/cron.d/` rather than root's crontab — see the warning below for why:

{% code overflow="wrap" %}
```shellscript
cat > /etc/cron.d/pve-etc-backup <<'EOF'
58 20 * * * root /usr/local/bin/pve-etc-backup.sh >> /var/log/pve-etc-backup.log 2>&1
EOF
```
{% endcode %}

{% hint style="danger" %}
**This backup covers `/etc` and `/etc/pve` — and nothing else.** Two things routinely live outside `/etc` and are silently lost in a bare-metal restore:

* **root's crontab**, which lives in `/var/spool/cron/crontabs/root`, *not* in `/etc`. That's exactly why the entry above goes in `/etc/cron.d/` instead: same schedule, but it actually gets backed up. Mind the extra `root` column — `/etc/cron.d` entries take a user field, plain crontabs don't.
* **`/root/.pbs-host-token`** — the token secret this very script reads. Unrecoverable; you'll have to reissue it (see step 7 of the restore method).

`/usr/local/bin` isn't backed up either, so keep a copy of your scripts on the ZFS pool (e.g. in `/tank/backup/`). It costs nothing and saves rewriting them from memory.
{% endhint %}

{% hint style="info" %}
The backup group is owned by whoever first created it. If you get `backup owner check failed`, the group belongs to a different user/token — either keep using that same identity, or reassign ownership (see [#fixing-backup-owner-check-failed](proxmox-backup.md#fixing-backup-owner-check-failed "mention")). Avoid `proxmox-backup-client snapshot forget` unless you're OK losing that group's snapshot history — it only works around the mismatch by discarding the old group so the new identity can recreate it from scratch.
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
zpool status tank      # expect ONLINE / "No known data errors" — confirm before going further
```

The `-f` is required because the pool was last touched by "another system" (your old install — or literally another motherboard). That message is expected and is **not** a sign of damage.

{% hint style="info" %}
PVE 9 ships a newer ZFS than your old install, so `zpool status` may add _"Some supported and requested features are not enabled"_. Ignore it. `zpool upgrade` is **one-way**, buys you nothing during a restore, and makes the pool unreadable by older ZFS — don't run it here.
{% endhint %}

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

A successful adopt prints `Access time update check successful.` followed by `TASK OK`. If it instead starts initialising a fresh chunk store, stop — you passed the wrong path or dropped `--reuse-datastore`.

### 4. Recover the old host config _first_

Before restoring a single guest, pull the old `/etc/pve` out of the backup. It's tiny (tens of KiB) and it tells you exactly what you're rebuilding — which storages existed, which guests existed, and the original secrets — instead of guessing.

You need credentials to talk to the temporary PBS. An API token beats putting the root password on a command line, but note that a freshly created token has **no permissions at all** until you grant them — even one belonging to `root@pam`:

```shellscript
proxmox-backup-manager user generate-token root@pam pve-restore     # prints the secret ONCE
proxmox-backup-manager acl update /datastore/backup DatastoreAdmin --auth-id 'root@pam!pve-restore'
```

{% hint style="warning" %}
`user generate-token` does **not** accept `--output-format` (it errors with _"schema does not allow additional properties"_). It prints a plain table, and the secret is shown exactly once — if you lose it, delete the token and reissue.
{% endhint %}

Then restore both config archives to a staging dir:

{% code overflow="wrap" %}
```shellscript
export PBS_PASSWORD='<token-secret>'
export PBS_FINGERPRINT="$(proxmox-backup-manager cert info | grep -oiE '([0-9a-f]{2}:){31}[0-9a-f]{2}')"
REPO='root@pam!pve-restore@127.0.0.1:backup'

proxmox-backup-client list --repository "$REPO"                                  # find host/<name>/<DATE>
proxmox-backup-client restore host/pve/<DATE> pve.pxar /root/pve-old --repository "$REPO"
proxmox-backup-client restore host/pve/<DATE> etc.pxar /root/etc-old --repository "$REPO"

cat /root/pve-old/storage.cfg          # the storages you must recreate (step 5)
ls  /root/pve-old/nodes/*/lxc/         # the guests you must restore (step 6)
```
{% endcode %}

{% hint style="success" %}
**`/etc/pve/priv` IS included in `pve.pxar`** — an earlier version of this page claimed it was lost, which is wrong and leads to unnecessary re-tokenising. What you get back:

* `priv/storage/<storeid>.pw` — the **original PBS storage token secret**
* `priv/token.cfg` — your PVE API token secrets
* `priv/authorized_keys` — the SSH keys that used to let you into the host

Reusing that original token in step 7 means the datastore's existing groups are already owned by the identity you authenticate as — so the "backup owner check failed" problem below **never occurs in the first place**. Recovering the secret is strictly better than reassigning ownership afterwards.
{% endhint %}

### 5. Recreate your storages

A fresh install has only `local` and `local-lvm`. Any guest whose rootfs lived elsewhere **cannot be restored until that storage exists again**. Copy the definitions out of `/root/pve-old/storage.cfg`, e.g.:

```shellscript
pvesm add zfspool tank --pool tank --content images,rootdir --mountpoint /tank
pvesm status                            # every storage should read "active"
```

{% hint style="danger" %}
**If a guest's disk still exists on the pool, `pct restore` replaces it.** A container whose rootfs lived on ZFS (`rootfs: tank:subvol-104-disk-0`) still has that subvol sitting on the pool, holding data _newer_ than your last backup.

A ZFS snapshot is **not** protection here — the snapshot lives inside the dataset and is destroyed along with it. Rename the dataset aside instead; it's instant and copies nothing:

```shellscript
zfs rename tank/subvol-104-disk-0 tank/subvol-104-preupgrade
```

Restore the guest, verify it, and only then `zfs destroy` the renamed copy.
{% endhint %}

### 6. Restore the guests

```shellscript
FP=$(proxmox-backup-manager cert info | grep -i fingerprint | grep -oiE '([0-9a-f]{2}:){31}[0-9a-f]{2}')
pvesm add pbs pbs-local --datastore backup --server 127.0.0.1 \
    --username 'root@pam!pve-restore' --password '<token-secret>' --fingerprint "$FP" --content backup

pvesm list pbs-local                                   # find the snapshot dates
pct restore 105 pbs-local:backup/ct/105/<DATE> --storage local-lvm
# repeat for every CT/VM (use qmrestore for VMs) — restore each onto the storage it came from
```

The restored config keeps everything: MAC addresses, static IPs, tags, `features`, bind mounts and raw `lxc.*` lines. Note that `pvesm list` reports the _uncompressed_ archive size, so a 38 GiB entry may be only ~20 GiB on disk. Large guests take a while — launch them with `nohup … &` and tail the log rather than holding an SSH session open.

{% hint style="warning" %}
If your new system disk is **smaller** than the old one, `local-lvm` may be too small for big guests — restore those onto the ZFS pool instead: `pct restore 104 pbs-local:backup/ct/104/<DATE> --storage tank`. Data on **bind-mounts** (e.g. `/tank/immich`) is _not_ in the backups; it stays on the pool and is just re-linked when the guest starts.
{% endhint %}

Leave the guests **stopped** for now — the PBS LXC has to take over the datastore first (step 7).

### Fixing "backup owner check failed"

{% hint style="success" %}
If you recovered the original token secret from `priv/storage/<storeid>.pw` in step 4 and reuse it in step 7, you can skip this section entirely — ownership already matches. It's kept for the case where that secret is genuinely gone.
{% endhint %}

{% hint style="danger" %}
Once you re-add PBS as PVE storage using a **freshly generated token**, your first scheduled backup after the restore will fail for every guest with `Error: backup owner check failed (your-new-token != proxmox@pbs)`. The pre-existing backup groups on the datastore are still owned by whatever identity created them originally (often the bare user `proxmox@pbs`, if the old storage used password auth instead of a token) — a brand new token/user is a _different_ identity as far as PBS ownership is concerned, even though it's the same physical datastore and the same PVE storage name. **This silently breaks every nightly backup until fixed** — check for it explicitly after any restore, don't assume backups are running just because the job is scheduled and PBS is reachable.
{% endhint %}

Reassign ownership of the existing groups to your new token instead of discarding their history. There's no CLI command for this (the web UI's "Change Owner" button on Datastore > Content calls it under the hood) — the same call also works from any host that can reach PBS, e.g. from the PVE host itself:

{% code overflow="wrap" %}
```shellscript
# run from PVE host, or from inside the PBS LXC — either works
TOKEN="$(cat /root/.pbs-host-token)"     # or whichever identity currently owns the datastore
for id in 100 101 102 103 104 105 106 107; do    # your guest IDs
  curl -sk -X POST \
    -H "Authorization: PBSAPIToken=proxmox@pbs!host-backup:$TOKEN" \
    --data-urlencode 'backup-type=ct' \
    --data-urlencode "backup-id=$id" \
    --data-urlencode 'new-owner=proxmox@pbs!pve-restore' \
    'https://192.168.1.105:8007/api2/json/admin/datastore/backup/change-owner'
done
```
{% endcode %}

Notes:

* The HTTP header is **`PBSAPIToken`**, not `PVEAPIToken` (that prefix is for PVE's own API and returns a plain-text `authentication failed` here — easy to mix up since it's the same token you use for PVE storage).
* Method is **POST**, not PUT.
* The calling identity needs `Datastore.Modify` on the group (`DatastoreAdmin` role covers it).
* Verify with `GET /api2/json/admin/datastore/backup/groups` (same auth header) — check the `owner` field per group.
* The owner is also readable straight off the disk: `cat /tank/backup/ct/<id>/owner`.
* This preserves every existing snapshot for that group; nothing is deleted.

### 7. Hand over to the real PBS LXC, remove the temporary one

{% hint style="danger" %}
Two PBS must **never** serve the same datastore at once. Stop the host PBS **before** starting the PBS LXC.
{% endhint %}

{% hint style="danger" %}
`apt autoremove --purge` will happily take **`proxmox-backup-client`** with it, because it arrived as a dependency of the server package. That's the binary your host backup script calls — so `/etc` backups break, and you won't notice until a run fails. Pin it first.
{% endhint %}

```shellscript
apt-mark manual proxmox-backup-client
systemctl disable --now proxmox-backup-proxy proxmox-backup
pvesm remove pbs-local
apt purge -y proxmox-backup-server && apt autoremove --purge -y
which proxmox-backup-client          # must still be there
pct start 105                        # the restored PBS LXC takes over
```

Re-add PBS as PVE storage, this time pointing at the LXC (`192.168.1.105`) — reusing the **original** identity and secret recovered in step 4:

{% code overflow="wrap" %}
```shellscript
pvesm add pbs pbs-backup --datastore backup --server 192.168.1.105 \
    --username 'proxmox@pbs!pve-restore' \
    --password "$(cat /root/pve-old/priv/storage/pbs-backup.pw)" \
    --fingerprint '<pbs-fingerprint>' --content backup
```
{% endcode %}

The LXC's certificate lives inside its own filesystem, so it came back with the container — **the fingerprint in your old `storage.cfg` is still valid**. Confirm with `pct exec 105 -- proxmox-backup-manager cert info | grep -i fingerprint`.

The one secret you genuinely cannot recover is `/root/.pbs-host-token`, because `/root` isn't backed up. Reissue it under the **same token name**, so the auth-id string is unchanged and the `host/<name>` group ownership still matches:

{% code overflow="wrap" %}
```shellscript
pct exec 105 -- proxmox-backup-manager user delete-token proxmox@pbs host-backup
pct exec 105 -- proxmox-backup-manager user generate-token proxmox@pbs host-backup
pct exec 105 -- proxmox-backup-manager acl update /datastore/backup DatastoreAdmin --auth-id 'proxmox@pbs!host-backup'
# then write the new secret to /root/.pbs-host-token (chmod 600)
```
{% endcode %}

Deleting a token also drops its ACL entries — that's why the third line is needed.

### 8. Cherry-pick the rest of /etc

Never blindly overwrite a running `/etc/pve`. From the staging dirs restored in step 4, copy back only what you need:

```shellscript
cp /root/pve-old/jobs.cfg        /etc/pve/jobs.cfg          # your backup job
cp /root/pve-old/user.cfg        /etc/pve/user.cfg          # users, API token IDs, ACLs
cp /root/pve-old/priv/token.cfg  /etc/pve/priv/token.cfg    # the token secrets themselves
```

Guest configs come back automatically with the guest restores in step 6, and `datacenter.cfg` is usually already correct. **Leave `/etc/network/interfaces` alone** unless you've diffed it first (see step 10).

Don't forget what lives _outside_ `/etc` and so isn't in the archive at all: your scripts (`/usr/local/bin/*.sh`), the cron entry, and `/root/.ssh/authorized_keys`. Old root SSH keys are recoverable from `/root/pve-old/priv/authorized_keys` — inspect with `ssh-keygen -lf` and merge rather than overwrite.

Finally delete the staging dirs, which contain secrets:

```shellscript
rm -rf /root/pve-old /root/etc-old
```

### 9. Rebuild what lives outside /etc

{% hint style="danger" %}
The `/etc` backup restores **systemd units, but not the things they point at.** After a reinstall you can have `scrutiny.timer` reporting `enabled`, a clean `systemctl status`, and a dashboard that loads fine — while the script the service actually executes doesn't exist. Nothing anywhere reports an error; you discover it days later when the data is stale. Walk this list explicitly instead of trusting a green `systemctl`.
{% endhint %}

| What | Where | How to get it back |
| ---- | ----- | ------------------ |
| Host backup script | `/usr/local/bin/pve-etc-backup.sh` | copy from `/tank/backup/` |
| vzdump PBS start hook | `/usr/local/bin/pbs-lxc-start-hook.sh` | copy from `/tank/backup/` |
| PBS host token | `/root/.pbs-host-token` | **unrecoverable** — reissue, see step 7 |
| Scrutiny collector + runner | `/opt/scrutiny/bin/`, `/root/scrutiny/scrutiny.sh` | [hdd-monitoring-proxmox.md](hdd-monitoring-proxmox.md "mention") |
| Extra packages | `smartmontools`, `lm-sensors` | `apt install` |
| Sensor modules | `/etc/modules` — `coretemp`, `nct6683` | cherry-pick from `/root/etc-old/modules` |
| Root SSH keys | `/root/.ssh/authorized_keys` | `/root/pve-old/priv/authorized_keys` |

{% hint style="warning" %}
**Scrutiny is the classic miss.** Web + InfluxDB live inside the LXC, so they return with the guest restore and the dashboard loads normally — but the **collector runs on the PVE host** and is gone. The dashboard then keeps showing the *old* disks and never the new ones, silently. Full procedure: [hdd-monitoring-proxmox.md](hdd-monitoring-proxmox.md "mention").
{% endhint %}

You can catch this whole class of failure in one command — it lists any restored unit whose `ExecStart` target is missing:

{% code overflow="wrap" %}
```shellscript
for f in /etc/systemd/system/*.service; do
  [ -e "$f" ] || continue
  u=$(basename "$f")
  b=$(systemctl show "$u" -p ExecStart --value 2>/dev/null | grep -oE "path=[^ ;]+" | head -1 | cut -d= -f2)
  case "$b" in /*) [ -e "$b" ] || echo "MISSING TARGET: $u -> $b";; esac
done
```
{% endcode %}

Empty output means every restored unit has its executable present. It deliberately checks **absolute paths only** — bare command names resolve through `PATH` and would otherwise throw false positives on stock units like `postfix` and `grub-common`. It also scans `.service` files directly rather than the enabled-unit list, because a service triggered by a timer is not itself "enabled" and would be skipped — which is exactly the Scrutiny case.

Mirroring every host-side script and binary to the pool (`/tank/backup/`) reduces this step to a handful of `cp` commands, for a few MB.

### 10. After a hardware change (new board / CPU / RAM)

Restored configs describe the _old_ machine. Extra traps when the rebuild also crosses a hardware change:

* **`cores:` can silently exceed the host.** A guest set to `cores: 16` on an 8-thread CPU still starts — LXC just caps it at what exists — so nothing errors and the wrong value sits there indefinitely. Compare against `nproc` and fix with `pct set <id> --cores 8`.
* **Network interface names.** `/etc/network/interfaces` names a specific NIC (`nic0`, `enp0s31f6`, …). If the new board's interface is named differently, restoring the old file drops the host off the network at next boot. Diff the two first — with PVE 9's interface pinning the name is often _identical_, in which case there's nothing to do.
* **PCIe passthrough.** `hostpciX` entries reference bus addresses that have almost certainly changed. Re-check against `lspci` before starting those guests.
* **Anything keyed to the host's MAC.** Guest MACs live in their own configs and survive; the host NIC's MAC is new, so a DHCP reservation or MAC-based filtering for the host needs updating.

Guest IPs are stored in the guest configs and come back unchanged, so from the LAN's point of view everything reappears where it was.

### Verify — don't assume

A restored system that _looks_ healthy can still have a broken backup chain, and you won't find out until a nightly job fails days later. Force one real run of each:

```shellscript
/usr/local/bin/pve-etc-backup.sh                        # expect "skipping mount point: pve", then both pxar archives
vzdump <smallest-ct-id> --storage pbs-backup --mode snapshot
```

The guest backup is the one that matters. If ownership is correct it completes and reports something like:

```
INFO: root.pxar: backup was done incrementally, reused 85.072 MiB (74.3%)
```

That reuse percentage is the proof you want: it means you're writing into the **existing** group with its dedup history intact, not silently starting a fresh one beside it.

Worth checking too: guests reachable on their old IPs, bind mounts remounted with real data (`pct exec <id> -- df -h /mnt/...`), and the services inside them healthy — several containers report `unhealthy` for a minute or two during startup before settling, so give them time before diagnosing.
