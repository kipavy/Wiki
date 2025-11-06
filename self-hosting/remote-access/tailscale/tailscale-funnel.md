---
description: >-
  Tailscale Funnel lets you route traffic from the broader internet to a local
  service running on a device in your Tailscale network (known as a tailnet).
---

# Tailscale Funnel

{% embed url="https://tailscale.com/kb/1223/funnel" %}

Tailscale Funnel offers simple, secure local service exposure via its Zero-Trust VPN, while a Reverse Proxy provides complete control over routing, performance, and public security.&#x20;

* Ease of use, one command, instant public HTTPS
* No port forwarding needed

It's really useful for apps that you need to be public and that asks your server IP only one time like Immich.

The major downside for me is that it can't be used with CNAME at the moment (see [https://github.com/tailscale/tailscale/issues/11563](https://github.com/tailscale/tailscale/issues/11563) )

### Setup for Proxmox

1. Install tailscale on LXC(s) running the service(s) using [https://login.tailscale.com/admin/machines/new-linux](https://login.tailscale.com/admin/machines/new-linux) (just copy paste the script)
2. Change ID and paste the following script in Proxmox shell (it gives /dev/net/tun access to the LXC):

```bash
ID=104

pct stop $ID
cat >> /etc/pve/lxc/$ID.conf <<EOF
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
EOF
pct start $ID
```

3. In the LXC you can now just proxy your service with:

```bash
tailscale funnel --bg 8080  # or whatever port you want to publish to internet
```

Note that if the LXC restarts, it will not persist, if you want you could do a cronjob or use tailscale sidecar (examples: [https://github.com/2Tiny2Scale/ScaleTail#tailscale-funnel](https://github.com/2Tiny2Scale/ScaleTail#tailscale-funnel)  [https://github.com/felix19350/tailscale-immich](https://github.com/felix19350/tailscale-immich))
