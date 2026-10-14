---
description: >-
  Turn a Debian machine into a router: assign interface addresses, hand out
  leases and resolve names with dnsmasq, and enable IP forwarding.
---

# Building a Linux Router

A router needs at least two network interfaces — one toward the upstream/LAN, one toward the private network it serves. This guide configures a Debian box (typically a [VM on two VDE switches](kvm-qemu-vde2.md)) to route between them, hand out DHCP leases, and act as a DNS server.

Example topology:

* `ens3` — uplink side, static `10.4.48.10/24`, gateway `10.4.48.1`
* `ens4` — private side, static `10.144.48.1/24` (this is the gateway the clients will use)

## 1. Assign static addresses to the interfaces

Edit `/etc/network/interfaces`:

```ini
allow-hotplug ens3
iface ens3 inet static
    address 10.4.48.10/24
    gateway 10.4.48.1

allow-hotplug ens4
iface ens4 inet static
    address 10.144.48.1/24
```

Point the router at a DNS resolver in `/etc/resolv.conf`:

```
nameserver 10.4.48.1
```

Then reboot (or `ifdown`/`ifup` each interface).

## 2. Enable IP forwarding

Turn it on now:

```bash
echo 1 > /proc/sys/net/ipv4/ip_forward
```

Make it permanent by uncommenting this line in `/etc/sysctl.conf`:

```ini
net.ipv4.ip_forward=1
```

## 3. DHCP + DNS with dnsmasq

```bash
apt install dnsmasq
```

Define the lease pool in a file under `/etc/dnsmasq.d/` (e.g. `dnsmasq.d/lan.conf`):

```ini
dhcp-range=10.144.48.3,10.144.48.254,255.255.255.0,12h
```

Pin static addresses to specific machines by MAC (handy for servers):

```ini
dhcp-host=42:12:01:02:03:04,apache,10.144.48.10,45m
dhcp-host=42:12:02:03:04:05,asterisk,10.144.48.20,45m
```

Give the hosts names so they resolve locally — `/etc/hosts`:

```
127.0.0.1   localhost
127.0.1.1   router
10.144.48.10 apache
10.144.48.20 asterisk
```

Restart dnsmasq to apply: `systemctl restart dnsmasq`.

## 4. Verify

**DHCP** — watch the bootp/DHCP exchange on the private side while a client renews its lease:

```bash
# on the router
tshark -ni ens4 port 67
```

```bash
# on a client: bounce the interface to force a new lease
su -
ifdown ens3 && ifup ens3
```

You should see the `DISCOVER → OFFER → REQUEST → ACK` exchange in the capture.

**DNS** — confirm name resolution by pinging one host from another by name:

```bash
# on the router
tshark -ni ens4 port 53
```

```bash
# on a client
ping asterisk
```

See [Packet Capture with tshark](packet-capture-tshark.md) for more on the capture side.
