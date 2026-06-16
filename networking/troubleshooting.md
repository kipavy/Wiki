---
description: Find open ports, listening sockets and trace connections when a network service misbehaves.
---

# Network Troubleshooting

A quick checklist when a service won't connect.

## Watch the conversation

Capture on the relevant interface and follow the TCP exchange — the **SYN** and **FIN** packets mark where a connection opens and closes:

```bash
tshark -i ens4 -f tcp
```

More on filters in [Packet Capture with tshark](packet-capture-tshark.md).

## Check the logs

```bash
less /var/log/syslog
```

## Scan a remote host's open ports

```bash
nmap IP_ADDRESS
```

## List local listening sockets

```bash
ss -tunlp          # TCP/UDP, numeric, listening, with owning process
ss -pan | grep 80  # everything touching port 80
```

`ss` flags: `-t` TCP, `-u` UDP, `-n` numeric, `-l` listening only, `-p` show process, `-a` all sockets.
