---
description: First things to do on a fresh Proxmox VE install (no-subscription repos).
---

# ⚙️ Proxmox Post-Install

## Switch to the no-subscription repos

A fresh PVE install ships with the **enterprise** repos enabled. Without a subscription they return `401 Unauthorized` and `apt update` / upgrades fail. On PVE 9 (Debian 13 "trixie") the repos use the new deb822 `.sources` format.

Add the PVE no-subscription repo:

{% code overflow="wrap" %}
```shellscript
cat > /etc/apt/sources.list.d/pve-no-subscription.sources <<'EOF'
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF
```
{% endcode %}

Disable the enterprise repos (deb822 way — add `Enabled: false` to each stanza):

```shellscript
printf '\nEnabled: false\n' >> /etc/apt/sources.list.d/pve-enterprise.sources
printf '\nEnabled: false\n' >> /etc/apt/sources.list.d/ceph.sources   # only if you don't use Ceph
apt update
```

{% hint style="info" %}
The community [PVE Post-Install script](https://community-scripts.github.io/ProxmoxVE/scripts?id=post-pve-install) does this (and a few other tweaks) interactively if you prefer.
{% endhint %}

{% hint style="warning" %}
The **subscription nag** on login is cosmetic — the no-subscription repo gets the exact same packages, just without the enterprise SLA/testing gate.
{% endhint %}
