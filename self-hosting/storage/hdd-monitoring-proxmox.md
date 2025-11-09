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

You can just change API\_ENDPOINT in the script to match your Scrutiny Web IP + Port and paste the script in proxmox shell.

```bash
#!/bin/bash

# CHANGE ME
API_ENDPOINT="http://192.168.1.xx:8080"


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

You'll now have access to Scrutiny Dashboard on [http://192.168.1.xx:8080](http://192.168.1.xx:8080/)

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

