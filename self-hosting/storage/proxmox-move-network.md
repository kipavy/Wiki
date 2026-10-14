---
description: >-
  Move a Proxmox host to another house / ISP box / subnet without losing access:
  a boot service re-addresses the host and every LXC/VM by itself, Tailscale
  comes back, you finish remotely.
---

# 🚚 Moving Proxmox to Another Network

Proxmox hosts and LXCs usually have **static IPs** (`192.168.1.75`, `.76`, …). Plug the server into a box that hands out another subnet (`192.168.0.x`, `10.0.0.x`) or uses another gateway (`.254` instead of `.1`) and nothing answers anymore: no web UI, no internet, so **no Tailscale either**, and you need a screen and a keyboard on site.

[`pve-renumber`](https://github.com/kipavy/Wiki/blob/main/scripts/pve-renumber.sh) fixes that. It is **agnostic**: it reads the host bridge and every LXC/VM config it finds, so a container added next year is handled without touching anything.

## How it works

At every boot, **before the guests start**:

1. If the configured gateway answers → normal boot, nothing happens (costs < 1 s).
2. Otherwise it asks the new box's DHCP server what network it hands out (`dhcpcd -T`: the offer is only *read*, no address is taken).
3. If that is a different network, it rewrites every host-side file keeping each host part — `.75` stays `.75`, `.76` stays `.76` — and the old gateway becomes the new one. Each address is first checked with an ARP probe: if it is already taken on the new LAN, the host falls back to the address DHCP offered and a guest is switched to DHCP.
4. It backs everything up, then reboots once.
5. After the reboot, once guests are up, it moves the Tailscale subnet route (`192.168.1.0/24` → `192.168.0.0/24`) and writes a report of the app configs that still point at the old network.

```
boot ── gateway answers? ──yes──▶ normal boot
             │no
             ▼
     DHCP offer = same network? ──yes──▶ normal boot (box just slow / no ping)
             │no (or no offer at all → leave everything alone)
             ▼
     rewrite host + LXC/VM configs ─▶ backup ─▶ reboot ─▶ Tailscale route + report
```

| Rewritten automatically | Only reported (you fix them) |
| --- | --- |
| `/etc/network/interfaces` (host IP + gateway) | App configs inside guests: `.env`, compose files, dashboards, NFS exports… |
| `/etc/hosts`, `/etc/resolv.conf` | Reverse-proxy targets (NPM keeps them in a database: fix them in its UI) |
| Every `/etc/pve/lxc/*.conf` (`ip=`, `gw=`, descriptions) | DNS rewrites (AdGuard / Pi-hole) |
| `/etc/pve/qemu-server/*.conf` (cloud-init `ipconfig`) | VMs that set their IP inside their own OS |
| `/etc/pve/storage.cfg` (PBS / NFS / SMB servers), firewall files | Scripts on the host (`/usr/local/bin`, `/root`) |
| Tailscale advertised routes (host or any LXC) | |

Nothing inside a guest is ever edited, and a clustered host (corosync) is refused.

## Install (once, on the Proxmox host)

```shellscript
curl -fsSL https://raw.githubusercontent.com/kipavy/Wiki/main/scripts/pve-renumber.sh -o /usr/local/sbin/pve-renumber
bash /usr/local/sbin/pve-renumber --install
pve-renumber --status
```

`--status` should say the gateway answers and the service is `enabled`. Remove it with `pve-renumber --uninstall`.

{% hint style="info" %}
It needs `dhcpcd` (to read the DHCP offer) and `busybox` (for `arping`); `--install` and `--status` warn if one is missing. Fix with `apt install dhcpcd-base busybox`.
{% endhint %}

## Moving day

{% stepper %}
{% step %}
### Before unplugging

* **Tailscale key expiry**: in the [admin console](https://login.tailscale.com/admin/machines), *Disable key expiry* on the subnet-router machine, or it may expire while the server is off.
* Optional, to skip step 3 below — let Tailscale approve any private subnet on its own. In *Access controls*, tag the router and add:

  ```json
  "tagOwners":     { "tag:subnet-router": ["autogroup:admin"] },
  "autoApprovers": { "routes": {
      "192.168.0.0/16": ["tag:subnet-router"],
      "10.0.0.0/8":     ["tag:subnet-router"],
      "172.16.0.0/12":  ["tag:subnet-router"] } }
  ```

  then on the router: `tailscale set --advertise-tags=tag:subnet-router` (tagged machines also never expire).
{% endstep %}

{% step %}
### At the new place

Plug the server into the box **with an Ethernet cable** and power it on. Allow ~5 minutes: it boots, detects the new network, re-addresses everything and reboots once.
{% endstep %}

{% step %}
### Get access back

The subnet router shows up in Tailscale again. In the admin console, **approve the new route** (*Machines → … → Edit route settings*) unless autoApprovers did it. Then, from anywhere:

```shellscript
ssh root@pve.lan             # names follow the move (see Local Names Instead of IPs)
pve-renumber --status
cat /root/pve-renumber-report.txt
```

Log of what happened: `/var/log/pve-renumber.log`.
{% endstep %}

{% step %}
### Fix the leftovers

With every app using [`.lan` names](proxmox-local-dns.md) instead of IPs, the report should be empty. If it lists something, that file still has an IP: replace it with a name rather than with the new IP, so the next move needs nothing either. Run `pve-renumber --scan` to check again.

**Docker Swarm (Dokploy)**: a swarm stays bound to the IP it was initialised with. If Dokploy does not come back after a move, re-anchor it in its container without losing services or data:

```shellscript
docker swarm init --force-new-cluster --advertise-addr "$(ip -4 -o addr show eth0 | awk '{split($4,a,"/"); print a[1]}')"
```

Single-node swarms in an LXC: use `--endpoint-mode dnsrr` on services that others reach by name (IPVS virtual IPs refuse connections in unprivileged containers).
{% endstep %}

{% step %}
### Protect the static IPs on the new box

Shrink the box's DHCP range so it stays **below** your static addresses (e.g. `.10`–`.74` when the host is `.75`), otherwise a phone may one day get the server's IP. On a Livebox: *Paramètres avancés → Réseau → DHCP*.
{% endstep %}
{% endstepper %}

## By hand (screen and keyboard on the server)

Same engine, interactive: it shows the plan and the full diff and asks before writing anything.

```shellscript
pve-renumber --dry-run                                  # what would change, writes nothing
pve-renumber                                            # probe DHCP, show the plan, ask, apply, reboot
pve-renumber --to 192.168.0.0/24 --gw 192.168.0.254     # no DHCP on the new LAN: give it yourself
```

Without the script installed: `bash <(curl -sL https://raw.githubusercontent.com/kipavy/Wiki/main/scripts/pve-renumber.sh)` (needs internet, so only once the host has some).

## Undo

Every run saves the original files in `/root/pve-renumber-backups/<date>/`:

```shellscript
ls /root/pve-renumber-backups/
pve-renumber --restore /root/pve-renumber-backups/20261014-191500
reboot
```

## When it will not save you

* **No DHCP on the new network** (rare with ISP boxes): nothing is changed, use `--to … --gw …` from the console.
* **No cable / box down**: it waits ~3 minutes, then leaves the config alone. Plug it in and reboot.
* **A cluster** (several Proxmox nodes): out of scope.
* **Wi-Fi only**: Proxmox expects Ethernet.

{% hint style="warning" %}
If the new LAN uses the **same subnet as your own home network** (both `192.168.1.x`), accepting the subnet route on your PC hijacks your own LAN. See [Tailscale Subnet routers](../remote-access/tailscale/tailscale-subnet-routers.md) and Tailscale's [4via6](https://tailscale.com/kb/1201/4via6-subnets) for overlapping subnets.
{% endhint %}
