---
description: >-
  Tutorial to setup Scrutiny HDD Monitoring & Alerting Dashboard on Proxmox
  (really useful for RAID setups)
---

# HDD Monitoring Proxmox

## Scrutiny setup

### Web+DB

use my scrutiny dokploy template

### Collector

{% embed url="https://github.com/AnalogJ/scrutiny/blob/master/docs/INSTALL_HUB_SPOKE.md#setting-up-a-spoke-without-docker" %}

must be on proxmox host since LXCs don't have access to S.M.A.R.T data (it may be possible via VMs with PCI passthrough but I don't recommend it)

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
OnUnitActiveSec=15min

[Install]
WantedBy=timers.target
EOF

systemctl enable --now scrutiny.timer
systemctl status scrutiny.timer
```

You'll now have access to Scrutiny Dashboard on [http://192.168.1.xx:8080](http://192.168.1.xx:8080/)

### Configuring Alerting

Scrutiny supports webhook alerting, we'll set up discord alerting
