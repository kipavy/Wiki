---
description: >-
  Subnet routers let you extend your Tailscale network (known as a tailnet) to
  include devices that don't or can't run the Tailscale client.
---

# Tailscale Subnet routers

{% embed url="https://tailscale.com/kb/1019/subnets" %}

{% embed url="https://diegocarrasco.com/access-multiple-lxc-containers-single-tailscale/#1-advertise-routes-on-tailscale-host" %}

I use tailcale subnet routers to avoid installing tailscale on each LXC, this lets me have one LXC dedicated to tailcale which gives me access to all my local network without having to install tailscale on each device.
