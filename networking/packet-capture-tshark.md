---
description: Capture and filter network traffic from the command line with tshark.
---

# Packet Capture with tshark

`tshark` is the terminal version of Wireshark — ideal on headless servers and routers.

```bash
apt install tshark
```

## Capturing on an interface

```bash
tshark -n -i ens4
```

* `-i` selects the interface to capture on.
* `-n` disables name resolution, so addresses and ports stay numeric (faster, no surprise DNS lookups).

## Capture filters

Capture filters use BPF syntax and are passed with `-f`:

```bash
tshark -f "port 22"                       # only traffic on port 22
tshark -f "host 10.107.3.19"              # only to/from this host
tshark -f "port 22 and host 10.107.3.19"  # combine conditions
tshark -f "port 22 and not host 10.107.3.19"  # exclude a host
tshark -f "tcp"                           # all TCP
```

{% hint style="info" %}
With a TCP capture you can spot the start and end of a connection by the **SYN** (open) and **FIN** (close) packets.
{% endhint %}

Common service ports to filter on: `67` (DHCP), `53` (DNS), `80`/`443` (HTTP/S), `22` (SSH).

## Generating test traffic with netcat

`netcat` is handy for poking a port to see it light up in the capture:

```bash
netcat 10.33.109.115 22     # try to reach the SSH port
netcat 10.33.109.115 2500   # try an arbitrary port
```

For pinpointing what's open or listening, see [Network Troubleshooting](troubleshooting.md).
