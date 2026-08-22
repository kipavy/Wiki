---
description: >-
  Tutorial to setup Scrutiny HDD Monitoring & Alerting Dashboard on Proxmox
  (really useful for RAID setups)
---

# HDD Monitoring Proxmox

## Scrutiny setup

### Web+DB

I opened a [PR](https://github.com/Dokploy/templates/pull/500) on Dokploy's Github, as of now it's pending but you can still use it by setting "Base URL" to: [https://kipavy-add-scrutiny-template.templates-70k.pages.dev/](https://kipavy-add-scrutiny-template.templates-70k.pages.dev/)&#x20;

If you don't want to use dokploy you can browse that link and just copy the docker-compose.yml from scrutiny template.

### Collector

{% hint style="info" %}
The collector must be on proxmox host since LXCs don't have access to S.M.A.R.T data (it may be possible via VMs with PCI passthrough but I don't recommend it and haven't tried it)
{% endhint %}

For reference:

{% embed url="https://github.com/AnalogJ/scrutiny/issues/534" %}

{% embed url="https://github.com/AnalogJ/scrutiny/blob/master/docs/INSTALL_HUB_SPOKE.md#setting-up-a-spoke-without-docker" fullWidth="false" %}

***

{% hint style="danger" %}
**The collector binary must match the Web image tag.** The Dokploy template above runs `ghcr.io/analogj/scrutiny:master-web`, but the script below downloads the **stable** `latest` collector. With a `master` web that binary is silently rejected — the collector logs `Device sda has no scrutiny UUID; skipping collection` and **no disk ever shows up**. If you use the `master`/`master-web` web, grab the matching `master` collector binary instead. There's no `master` binary on the releases page, so extract it from the collector image (run this in an LXC that has Docker, then copy it to the host):

{% code overflow="wrap" %}
```bash
# inside a Docker LXC (e.g. your docker CT):
docker create --name tmp-scm ghcr.io/analogj/scrutiny:master-collector
docker cp tmp-scm:/opt/scrutiny/bin/scrutiny-collector-metrics /root/scm
docker container rm tmp-scm
# then, on the PVE host:
pct pull <docker-ct-id> /root/scm /opt/scrutiny/bin/scrutiny-collector-metrics-linux-amd64
chmod +x /opt/scrutiny/bin/scrutiny-collector-metrics-linux-amd64
```
{% endcode %}
{% endhint %}

You can just change API\_ENDPOINT in the script to match your Scrutiny Web IP + Port and paste the script in proxmox shell.

{% hint style="warning" %}
Use the **published** port, not the container's internal one. The Dokploy template maps `8087 -> 8080`, so the Web UI *and* the collector's `--api-endpoint` are both `http://<web-ip>:8087`. Port `8080` only exists inside the container — pointing the collector at it just times out from the host, with no disks ever appearing and no obvious error saying why.

Check yours and use the left-hand side of the `->`:

```bash
pct exec <docker-ct-id> -- docker ps --format '{{.Names}}\t{{.Ports}}' | grep -i scrutiny
```
{% endhint %}

```bash
#!/bin/bash

# CHANGE ME
API_ENDPOINT="http://192.168.1.xx:8087"   # published port, NOT the container-internal 8080


############# Scrutiny Collector ###################
apt install -y smartmontools
INSTALL_DIR="/opt/scrutiny"
BIN_DIR="$INSTALL_DIR/bin"
LATEST_RELEASE_URL="https://github.com/AnalogJ/scrutiny/releases/latest/download/scrutiny-collector-metrics-linux-amd64"

mkdir -p $BIN_DIR
curl -L $LATEST_RELEASE_URL -o $BIN_DIR/scrutiny-collector-metrics-linux-amd64
chmod +x $BIN_DIR/scrutiny-collector-metrics-linux-amd64

############## Scrutiny Service ####################
mkdir -p /root/scrutiny
cat << EOF > /root/scrutiny/scrutiny.sh
#!/bin/bash
/opt/scrutiny/bin/scrutiny-collector-metrics-linux-amd64 run --api-endpoint "$API_ENDPOINT" 2>&1 | tee /var/log/scrutiny.log
EOF
chmod +x /root/scrutiny/scrutiny.sh

cat << 'EOF' > /etc/systemd/system/scrutiny.service
[Unit]
Description="Scrutiny Collector"
Requires=scrutiny.timer

[Service]
Type=simple
ExecStart=/root/scrutiny/scrutiny.sh
User=root
EOF

cat << 'EOF' > /etc/systemd/system/scrutiny.timer
[Unit]
Description="Timer for the scrutiny.service"

[Timer]
Unit=scrutiny.service
OnBootSec=5min
OnUnitActiveSec=12h

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now scrutiny.timer
systemctl status scrutiny.timer
```

You'll now have access to Scrutiny Dashboard on [http://192.168.1.xx:8087](http://192.168.1.xx:8087/)

### After a host reinstall (restore)

{% hint style="warning" %}
Web + InfluxDB live **in the LXC**, so they come back with your PBS restore — but the **collector lives on the PVE host** and is wiped when you reinstall PVE. Until you re-set it up, Scrutiny keeps showing the **old disks** (historical InfluxDB data) and **never shows the new ones** (nothing is collecting). That's the symptom, not a data-association bug.
{% endhint %}

1. Re-install the collector on the host — **matching the Web tag** (see the version warning above; for the `master` template, extract the `master` binary).
2. Run it once to confirm: `/opt/scrutiny/bin/scrutiny-collector-metrics-linux-amd64 run --api-endpoint "$API_ENDPOINT"`. New disks appear immediately.
3. **Remove ghost disks** (drives you've physically pulled — they never disappear on their own). Either the trash icon in the Web UI, or via the API with the device's WWN (get it from `…/api/summary`):

```bash
curl -X DELETE http://192.168.1.xx:8087/api/device/0x50XXXXXXXXXXXXXX
```

{% hint style="danger" %}
**Delete by WWN, and only for drives that are physically gone.** After a restore your *surviving* drives will also show the wrong `/dev/sdX` — letters shift whenever a disk is added or removed, and Scrutiny shows the name captured at the **last successful collection**, which is stale until the collector runs again.

Those are **not** ghosts. Scrutiny keys devices by **WWN**, so real drives re-associate correctly on their own and their names fix themselves after one collection. Deleting one because its `sdX` looks wrong destroys that drive's whole SMART history — power-on hours, temperature trend, error counts — and it does not come back.

Tell them apart by **serial**, never by device name:

{% code overflow="wrap" %}
```bash
# what Scrutiny thinks it has
curl -s http://192.168.1.xx:8087/api/summary | grep -oE '"wwn":"[^"]*","device_name":"[^"]*","device_uuid":"[^"]*","device_serial_id":"[^"]*"'
# what is actually plugged in
for d in /dev/sd?; do echo "$d $(smartctl -i $d | grep -iE '^Serial Number|^Device Model' | tr -s ' ' | tr '\n' ' ')"; done
```
{% endcode %}

A WWN in the first list with no counterpart in the second is a genuine ghost — delete that one. Everything else just needs the collector to run once. Dump `…/api/summary` to a file before deleting anything, so a mistake is at least reconstructible.
{% endhint %}

{% hint style="info" %}
Put the collector cron/timer in a host-backed-up location if you can. A systemd unit under `/etc/systemd/system` (like the script above) **is** captured by the `/etc` backup — but the **binary** in `/opt/scrutiny` is not, so you'll still re-fetch it after a bare-metal restore.
{% endhint %}

### Configuring Alerting

Scrutiny supports webhook alerting through [Shouttr](https://containrrr.dev/shoutrrr/services/overview/), we'll set up discord alerting.

1. Get a discord webhook: create a server and a channel dedicated for Scrutiny

<figure><img src="../../.gitbook/assets/{D2761BFF-6926-4CEB-AFBD-08484B05736C}.png" alt=""><figcaption></figcaption></figure>

2. Create config/scrutiny.yaml based [example.scrutiny.yaml](https://github.com/AnalogJ/scrutiny/blob/master/example.scrutiny.yaml#L61-L85) with discord webhook matching [shouttr's url format](https://containrrr.dev/shoutrrr/v0.8/services/discord/#url_format).
3. You can try to trigger an alert with

```bash
curl -X POST http://192.168.1.xx:XXXX/api/health/notify
```

If it doesn't work try to restart or rebuild the scrutiny container.

