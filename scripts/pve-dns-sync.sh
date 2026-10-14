#!/usr/bin/env bash
# pve-dns-sync.sh - publish a DNS name for the Proxmox host, the ISP box and
# every guest (<hostname>.lan) into AdGuard Home, from the Proxmox configs.
#
#   curl -fsSL https://raw.githubusercontent.com/kipavy/Wiki/main/scripts/pve-dns-sync.sh -o /usr/local/sbin/pve-dns-sync
#   pve-dns-sync --install
#
# Single source of truth = /etc/pve (which pve-renumber keeps right after a
# move): apps point at docker.lan, never at 192.168.1.149.
# The records go into a marked block of the /etc/hosts file *inside* the
# AdGuard container; AdGuard Home (hostsfile_enabled: true) serves them
# immediately, no API credentials needed. The rest of that file is untouched.
# Docs: self-hosting/storage/proxmox-move-network.md

URL=https://raw.githubusercontent.com/kipavy/Wiki/main/scripts/pve-dns-sync.sh
INSTALL_PATH=/usr/local/sbin/pve-dns-sync

ROOT=${ROOT:-}
PCT=${PCT:-pct}
SYSTEMCTL=${SYSTEMCTL:-systemctl}
CONFIG=${CONFIG:-$ROOT/etc/default/pve-dns-sync}

DNS_CT=''          # CT running AdGuard Home (config file)
DOMAIN=lan         # names are <name>.$DOMAIN
HOSTS_FILE=/etc/hosts
# AdGuard DNS rewrites whose answer must follow a guest's IP, "domain=name ...",
# e.g. REWRITES="*.kipavy.fr=npmplus kipavy.fr=npmplus". Hosts files cannot do
# wildcards, and a rewrite to a name only returns a CNAME that some clients
# (Windows, glibc) never chase, so the IP itself is kept up to date.
REWRITES=''
ADGUARD_YAML=/opt/AdGuardHome/AdGuardHome.yaml
DNS_RESTART='rc-service adguardhome restart'
BEGIN='# --- BEGIN pve-dns-sync (generated from /etc/pve, do not edit) ---'
END='# --- END pve-dns-sync ---'

DRY_RUN=0

log()  { printf '%s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

load_config() {
  # shellcheck source=/dev/null
  [[ -f $CONFIG ]] && . "$CONFIG"
  [[ -n $DNS_CT ]] || die "set DNS_CT=<id of the AdGuard container> in ${CONFIG#"$ROOT"}"
  [[ $DOMAIN =~ ^[a-z0-9.-]+$ ]] || die "invalid DOMAIN: $DOMAIN"
}

dns_label() { # dns_label <name> -> lower-case DNS-safe label, empty if hopeless
  local s=${1,,}
  s=${s//_/-}
  s=$(printf '%s' "$s" | tr -cd 'a-z0-9.-')
  s=${s#-}; s=${s%-}
  printf '%s' "$s"
}

host_record() { # -> "ip name" for the host and "ip box" for its gateway
  local line addr gw
  line=$(awk '
    /^iface[ \t]/ { if (cur != "" && gw != "" && addr != "") { print addr, gw; exit } cur = ($3 == "inet") ? $2 : ""; addr = gw = ""; next }
    /^[ \t]+address[ \t]/ { split($2, a, "/"); if (a[1] ~ /^[0-9.]+$/) addr = a[1] }
    /^[ \t]+gateway[ \t]/ { if ($2 ~ /^[0-9.]+$/) gw = $2 }
    END { if (cur != "" && gw != "" && addr != "") print addr, gw }
  ' "$ROOT/etc/network/interfaces" | head -n 1)
  [[ -n $line ]] || return 0
  read -r addr gw <<< "$line"
  printf '%s %s\n' "$addr" "$(dns_label "$(host_name)")"
  printf '%s %s\n' "$gw" box
}

host_name() {
  if [[ -n $ROOT ]]; then cat "$ROOT/etc/hostname"; else hostname -s; fi
}

guest_records() { # -> "ip name [alias...]" for every guest with a known IPv4
  local f kind id name ip tags fields
  for f in "$ROOT"/etc/pve/lxc/*.conf "$ROOT"/etc/pve/qemu-server/*.conf; do
    [[ -f $f ]] || continue
    kind=ct; [[ $f == */qemu-server/* ]] && kind=vm
    id=$(basename "$f" .conf)
    # live section only (snapshots follow the first [section])
    fields=$(awk -v kind="$kind" '
      /^\[/ { exit }
      kind == "ct" && /^hostname:/ { name = $2 }
      kind == "vm" && /^name:/ { name = $2 }
      /^tags:/ { tags = $2 }
      /^(net|ipconfig)[0-9]+:/ && ip == "" {
        if (match($0, /ip=[0-9.]+\//)) ip = substr($0, RSTART + 3, RLENGTH - 4)
        else if ($0 ~ /ip=dhcp/) ip = "dhcp"
      }
      END { print (name == "" ? "-" : name), (ip == "" ? "-" : ip), (tags == "" ? "-" : tags) }' "$f")
    read -r name ip tags <<< "$fields"
    [[ $name != - ]] || name=$kind$id
    if [[ $ip == dhcp && $kind == ct ]]; then ip=$(live_ip "$id"); fi
    [[ $ip =~ ^[0-9]+(\.[0-9]+){3}$ ]] || continue
    printf '%s %s%s\n' "$ip" "$(dns_label "$name")" "$(aliases "$tags")"
  done
}

aliases() { # aliases <tags> -> " alias1 alias2" from Proxmox tags "dns-<alias>"
  local t out=''
  [[ $1 != - ]] || return 0
  for t in ${1//[;,]/ }; do
    [[ $t == dns-* ]] && out+=" $(dns_label "${t#dns-}")"
  done
  printf '%s' "$out"
}

live_ip() { # address a DHCP container currently holds (running containers only)
  $PCT exec "$1" -- ip -4 -o addr show scope global 2>/dev/null \
    | awk '{ split($4, a, "/"); print a[1]; exit }'
}

render_block() { # the full marked block, names qualified with $DOMAIN
  local ip names n line
  printf '%s\n' "$BEGIN"
  { host_record; guest_records; } | sort -t . -k1,1n -k2,2n -k3,3n -k4,4n | while read -r ip names; do
    [[ -n $names ]] || continue
    line=$ip
    for n in $names; do [[ -n $n ]] && line+=" $n.$DOMAIN"; done
    printf '%s\n' "$line"
  done
  printf '%s\n' "$END"
}

# Inside the DNS container (plain sh: Alpine/BusyBox or Debian). Reads the new
# block on stdin, replaces the old block (or appends it), and rewrites the file
# in place (same inode: AdGuard Home watches it). Prints "unchanged"/"updated".
APPLY_SH='f=$1; new=$(cat); [ -f "$f" ] || : > "$f"
cur=$(awk -v b="$2" -v e="$3" "\$0==b{p=1} p{print} \$0==e{p=0}" "$f")
[ "$cur" = "$new" ] && { echo unchanged; exit 0; }
tmp=$(mktemp)
awk -v b="$2" -v e="$3" "\$0==b{skip=1; next} \$0==e{skip=0; next} !skip" "$f" > "$tmp"
printf "%s\n" "$new" >> "$tmp"
cat "$tmp" > "$f"; rm -f "$tmp"; echo updated'

render_rewrites() { # render_rewrites <block> -> "domain ip" for each REWRITES entry
  local block=$1 pair dom name ip
  for pair in $REWRITES; do
    dom=${pair%%=*}; name=${pair#*=}
    ip=$(printf '%s\n' "$block" | awk -v n="$name.$DOMAIN" '{ for (i = 2; i <= NF; i++) if ($i == n) { print $1; exit } }')
    if [[ -n $ip ]]; then printf '%s %s\n' "$dom" "$ip"; else warn "rewrite $dom: no record named $name.$DOMAIN"; fi
  done
}

# Inside the DNS container: set the answer of the listed rewrites in AdGuard's
# YAML (stdin: "domain ip" lines). Prints "changed" only when the file changed.
REWRITE_SH='y=$1; want=$(mktemp); cat > "$want"; tmp=$(mktemp)
if awk "NR == FNR { w[\$1] = \$2; next }
  /^[ \t]*- domain: / { d = \$0; sub(/^[ \t]*- domain: /, \"\", d); gsub(/[^A-Za-z0-9.*_-]/, \"\", d)
                        cur = (d in w) ? d : \"\"; print; next }
  cur != \"\" && /^[ \t]*answer: / { m = \$0; sub(/answer: .*/, \"answer: \" w[cur], m)
                                     if (m != \$0) n++; print m; cur = \"\"; next }
  { print }
  END { exit n ? 0 : 1 }" "$want" "$y" > "$tmp"; then cat "$tmp" > "$y"; echo changed; else echo unchanged; fi
rm -f "$want" "$tmp"'

sync() {
  local block result rewrites
  load_config
  block=$(render_block)
  rewrites=$(render_rewrites "$block")
  if [[ $DRY_RUN == 1 ]]; then
    printf '%s\n' "$block"
    [[ -z $rewrites ]] || { printf '\nAdGuard rewrites:\n'; printf '%s\n' "$rewrites" | sed 's/ / -> /; s/^/  /'; }
    return 0
  fi
  result=$(printf '%s\n' "$block" | $PCT exec "$DNS_CT" -- sh -c "$APPLY_SH" sh "$HOSTS_FILE" "$BEGIN" "$END") \
    || die "could not update $HOSTS_FILE in CT $DNS_CT (is it running?)"
  [[ $result == updated ]] && log "pve-dns-sync: $(( $(printf '%s\n' "$block" | wc -l) - 2 )) records published to CT $DNS_CT"
  if [[ -n $rewrites ]]; then
    result=$(printf '%s\n' "$rewrites" | $PCT exec "$DNS_CT" -- sh -c "$REWRITE_SH" sh "$ADGUARD_YAML") \
      || die "could not update the rewrites in $ADGUARD_YAML"
    if [[ $result == changed ]]; then
      log "pve-dns-sync: AdGuard rewrites updated ($(printf '%s\n' "$rewrites" | tr '\n' ' ')), restarting AdGuard"
      $PCT exec "$DNS_CT" -- sh -c "$DNS_RESTART" >/dev/null
    fi
  fi
  return 0
}

install_service() {
  local self dest=$ROOT$INSTALL_PATH
  self=$(readlink -f "$0" 2>/dev/null || true)
  [[ -f $self && $self != /dev/* && $self != /proc/* ]] \
    || die "--install needs the script saved as a file: curl -fsSL $URL -o $INSTALL_PATH && bash $INSTALL_PATH --install"
  [[ $self == "$dest" ]] || install -m 0755 "$self" "$dest"
  if [[ ! -f $CONFIG ]]; then
    mkdir -p "$(dirname "$CONFIG")"
    printf '# CT id running AdGuard Home, and the local domain\nDNS_CT=%s\nDOMAIN=%s\n' "${DNS_CT:-}" "$DOMAIN" > "$CONFIG"
    log "Wrote ${CONFIG#"$ROOT"}: set DNS_CT to the AdGuard container id."
  fi
  cat > "$ROOT/etc/systemd/system/pve-dns-sync.service" <<EOF
[Unit]
Description=Publish <guest>.lan names from /etc/pve into AdGuard Home

[Service]
Type=oneshot
ExecStart=$INSTALL_PATH
EOF
  cat > "$ROOT/etc/systemd/system/pve-dns-sync.timer" <<EOF
[Unit]
Description=Keep <guest>.lan names in sync with /etc/pve

[Timer]
OnBootSec=1min
OnUnitActiveSec=2min

[Install]
WantedBy=timers.target
EOF
  $SYSTEMCTL daemon-reload
  $SYSTEMCTL enable --now pve-dns-sync.timer
  log "Installed $INSTALL_PATH, pve-dns-sync.timer runs every 2 minutes."
}

usage() {
  cat <<'EOF'
Usage: pve-dns-sync [--dry-run | --install | -h]

Publish <hostname>.lan for the Proxmox host ("pve"), the ISP box ("box") and
every LXC/VM into AdGuard Home's hosts file, from /etc/pve. Extra names: add a
Proxmox tag "dns-<alias>" to a guest (tag dns-pbs -> pbs.lan).

  (no option)   sync now (only writes when something changed)
  --dry-run     print the block that would be published
  --install     install the script + a systemd timer (every 2 min)
EOF
}

main() {
  set -euo pipefail
  case ${1:-} in
    '') sync ;;
    --dry-run) DRY_RUN=1; sync ;;
    --install) install_service ;;
    -h|--help) usage ;;
    *) usage >&2; die "unknown option: $1" ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
