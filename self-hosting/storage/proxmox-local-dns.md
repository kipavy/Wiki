---
description: >-
  Give every Proxmox guest a DNS name (docker.lan, pbs.lan…) generated from the
  Proxmox config and served by AdGuard Home, so apps never hard-code a LAN IP.
---

# 🏷️ Local Names Instead of IPs

Hard-coded LAN addresses (`192.168.1.149:2283` in a reverse proxy, a dashboard, a script…) are what breaks when the server moves to another network. Here every guest gets a name **generated from `/etc/pve`**, and every app uses that name:

```
/etc/pve (hostnames + IPs)  ──pve-dns-sync──▶  AdGuard Home  ──▶  docker.lan, pbs.lan, pve.lan, box.lan…
        ▲                                         ▲
  pve-renumber keeps it right             reached via Tailscale split DNS
  after a move                            (stable 100.x address)
```

After a move, [`pve-renumber`](proxmox-move-network.md) rewrites `/etc/pve`, `pve-dns-sync` republishes the names within 2 minutes, and **nothing else needs editing**.

## The names

[`pve-dns-sync`](https://github.com/kipavy/Wiki/blob/main/scripts/pve-dns-sync.sh) publishes:

| Name | Points to |
| --- | --- |
| `pve.lan` | the Proxmox host |
| `box.lan` | the ISP box (the host's gateway) |
| `<hostname>.lan` | every LXC/VM: static IP from its config, DHCP lease of a running CT, cloud-init IP of a VM |
| `<alias>.lan` | extra names: add a Proxmox **tag** `dns-<alias>` to the guest (tag `dns-pbs` → `pbs.lan`) |

It writes them into a marked block of `/etc/hosts` **inside the AdGuard container** (`hostsfile_enabled: true` makes AdGuard serve them instantly, no API key needed), and keeps the AdGuard rewrites `*.kipavy.fr` / `kipavy.fr` pointed at the reverse proxy's current IP. A wildcard can't live in a hosts file, and a rewrite to a *name* only returns a CNAME that Windows and glibc don't follow, so the IP itself is kept in sync. AdGuard is restarted only when that IP actually changes.

```shellscript
curl -fsSL https://raw.githubusercontent.com/kipavy/Wiki/main/scripts/pve-dns-sync.sh -o /usr/local/sbin/pve-dns-sync
cat > /etc/default/pve-dns-sync <<'EOF'
DNS_CT=102          # container running AdGuard Home
DOMAIN=lan
REWRITES="*.kipavy.fr=npmplus kipavy.fr=npmplus"
EOF
bash /usr/local/sbin/pve-dns-sync --install   # systemd timer, every 2 minutes
pve-dns-sync --dry-run                        # what is published
```

## Who resolves through AdGuard

| Client | How |
| --- | --- |
| Containers | Proxmox `nameserver` option: `pct set <id> --nameserver "192.168.1.95 1.1.1.1"` (in `/etc/pve`, so `pve-renumber` moves it) |
| Host | `/etc/resolv.conf`: AdGuard first, `1.1.1.1` second, `options timeout:2` |
| Reverse proxy (NPMplus, CT101) | **AdGuard only**: nginx round-robins its resolvers, with `1.1.1.1` listed half the `.lan` lookups fail. `tailscale set --accept-dns=false` in that CT so MagicDNS doesn't take over |
| DHCP containers | Give them a static IP instead (above the box's DHCP range). The `dhcpcd` started by ifupdown keeps rewriting `resolv.conf` with the box's DNS, and does not reload `nohook resolv.conf` from its config |
| Your devices, anywhere | Tailscale split DNS: `kipavy.fr` and `lan` → AdGuard's **Tailscale IP** |

AdGuard runs its own Tailscale client (`tailscale up --accept-dns=false --hostname=adguard`) only to get a `100.x` address that never changes. The split DNS in the Tailscale admin console therefore never needs editing after a move.

## AdGuard must not fall over

Everything named depends on it, so:

* **Starts first**: `pct set 102 --startup order=1,up=15`.
* **Supervised**: the OpenRC service uses `supervisor="supervise-daemon"` with `respawn_max=0`, so a crash is restarted within 3 s (tested with `kill -9`).
* **Never self-updates**: `command_args="--no-check-update"`. Upgrade by hand, after a PBS backup.
* **Backups never depend on DNS**: `storage.cfg` keeps the PBS IP (moved by `pve-renumber`), and the `/etc` backup script reads it from there:

  ```shellscript
  PBS_SERVER=$(awk '/^pbs: pbs-backup$/ {f=1; next} /^[a-z]+: / {f=0} f && $1 == "server" {print $2; exit}' /etc/pve/storage.cfg)
  ```

## Using the names

* Reverse proxy targets: `docker.lan:2283`, `pve.lan:8006`, `pbs.lan:8007`. NPMplus resolves at request time (`resolver local=on valid=10s`), so a missing name breaks one site, not nginx. For the proxy's own admin UI use `127.0.0.1:81`.
* Dashboards / `.env`: `PROXMOX_URL=pve.lan:8006` ([glance-template](https://github.com/kipavy/glance-template)). With Dokploy, change the variable in Dokploy too or a redeploy brings the IP back.
* Cloudflare tunnel public hostnames: service `http://docker.lan:2283`.
* NFS exports: allow the private ranges (`10.0.0.0/8 172.16.0.0/12 192.168.0.0/16`) rather than the current `/24`.
