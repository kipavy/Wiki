---
description: >-
  Hands-on networking and telecommunications notes: virtual networking,
  building routers, packet capture, broadcast TV, and VoIP.
icon: network-wired
---

# 🌐 Networking

This section collects practical, lab-tested networking how-tos. Most of it is built around Debian and the KVM/QEMU virtualization stack, so you can reproduce a whole network (router + servers + clients) on a single machine.

* [Virtual Networking with KVM/QEMU & VDE2](kvm-qemu-vde2.md) — spin up VMs, wire them together with virtual switches, and edit disk images offline.
* [Building a Linux Router](linux-router.md) — turn a Debian VM into a router with DHCP, DNS and IP forwarding via `dnsmasq`.
* [Packet Capture with tshark](packet-capture-tshark.md) — capture and filter traffic from the command line.
* [Network Troubleshooting](troubleshooting.md) — find open ports, listening sockets and trace connections.
* [DVB & SDR — Broadcast TV Analysis](dvb-sdr.md) — scan, watch and dissect DVB-T streams; stream them over multicast.
* [Asterisk VoIP](asterisk-voip.md) — a softswitch with a Bluetooth phone gateway.
