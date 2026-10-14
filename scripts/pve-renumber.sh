#!/usr/bin/env bash
# pve-renumber.sh - move a standalone Proxmox VE host and ALL its guests to a new
# LAN subnet (new house, new ISP box), keeping every host part: .75 stays .75.
#
#   bash <(curl -sL https://raw.githubusercontent.com/kipavy/Wiki/main/scripts/pve-renumber.sh)
#
# Agnostic: it discovers the host bridge, every LXC/VM config and every IP in
# them; nothing about a particular setup is hard-coded.
# Docs: self-hosting/storage/proxmox-move-network.md
#
# Never edits files inside guests (it only reports leftovers) and never touches
# a cluster (corosync) setup.

URL=https://raw.githubusercontent.com/kipavy/Wiki/main/scripts/pve-renumber.sh
INSTALL_PATH=/usr/local/sbin/pve-renumber

# External commands and paths, overridable for testing.
ROOT=${ROOT:-}
PING=${PING:-ping}
ARPING=${ARPING:-busybox arping}
DHCPCD=${DHCPCD:-dhcpcd}
PCT=${PCT:-pct}
SYSTEMCTL=${SYSTEMCTL:-systemctl}
HOST_TAILSCALE=${HOST_TAILSCALE:-tailscale}  # the host binary; inside guests it is always "tailscale"
STATE_FILE=${STATE_FILE:-$ROOT/var/lib/pve-renumber/state}
BACKUP_ROOT=${BACKUP_ROOT:-$ROOT/root/pve-renumber-backups}
REPORT_FILE=${REPORT_FILE:-$ROOT/root/pve-renumber-report.txt}
AUTO_WAIT=${AUTO_WAIT:-180}      # boot: seconds to wait for the gateway or a DHCP offer
AUTO_GUARD=${AUTO_GUARD:-1800}   # boot: never renumber twice within this many seconds
POST_DELAY=${POST_DELAY:-30}     # after a move: let guests (tailscaled) settle before --post
SCAN_DIRS=${SCAN_DIRS:-/etc /opt /root /srv /home /usr/local}
NOW=${NOW:-}                     # epoch override for tests

DRY_RUN=0

# --- output helpers -------------------------------------------------------

log()  { printf '%s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
now()  { if [[ -n $NOW ]]; then echo "$NOW"; else date +%s; fi; }

# --- prompts ---------------------------------------------------------------
# All prompts read /dev/tty, never stdin: under `bash <(curl ...)` or `curl | bash`
# stdin may be the script itself, and a plain `read` would answer its own prompts.

has_tty() { { : < /dev/tty; } 2>/dev/null; }   # -r is not enough without a controlling tty

confirm() { # confirm <prompt>  -> 0 only on y/Y; default is No
  local prompt=$1 reply=''
  if ! has_tty; then
    warn "no tty available; refusing to assume consent for: $prompt"
    return 1
  fi
  printf '%s [y/N] ' "$prompt" > /dev/tty
  IFS= read -r reply < /dev/tty || return 1
  [[ $reply == y || $reply == Y ]]
}

ask() { # ask <prompt> [default] -> prints the answer
  local prompt=$1 def=${2:-} reply=''
  has_tty || return 1
  if [[ -n $def ]]; then printf '%s [%s] ' "$prompt" "$def" > /dev/tty
  else printf '%s ' "$prompt" > /dev/tty; fi
  IFS= read -r reply < /dev/tty || return 1
  printf '%s\n' "${reply:-$def}"
}

# --- IPv4 helpers ----------------------------------------------------------

is_ip() { # is_ip <a.b.c.d>
  local IFS=. o
  [[ $1 =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || return 1
  for o in $1; do (( o <= 255 )) || return 1; done
}

ip2int() { local IFS=. a b c d; read -r a b c d <<< "$1"; echo $(( (a << 24) | (b << 16) | (c << 8) | d )); }
int2ip() { local n=$1; echo "$(( (n >> 24) & 255 )).$(( (n >> 16) & 255 )).$(( (n >> 8) & 255 )).$(( n & 255 ))"; }

net_of() { # net_of <ip> <prefix> -> network address
  local n size
  n=$(ip2int "$1"); size=$(( 1 << (32 - $2) ))
  int2ip $(( n - n % size ))
}

in_net() { # in_net <ip> <net> <prefix>
  [[ $(net_of "$1" "$3") == "$(net_of "$2" "$3")" ]]
}

parse_cidr() { # parse_cidr <a.b.c.d/nn> -> "net prefix"
  local ip=${1%/*} p=${1#*/}
  [[ $1 == */* ]] && is_ip "$ip" && [[ $p =~ ^[0-9]+$ ]] && (( p >= 8 && p <= 30 )) || return 1
  echo "$(net_of "$ip" "$p") $p"
}

# --- the remapper ------------------------------------------------------------
# One implementation, used for every file and every single address: each IPv4
# inside the old subnet keeps its host part in the new subnet; the old gateway
# becomes the new gateway (ISP boxes disagree on .1 vs .254); a matching /prefix
# suffix follows a prefix-length change. Extra "old=new" args force an address.
# Addresses that do not fit the new subnet are left alone and named on stderr.

REMAP_PL='
use strict; use warnings;
my ($on, $op, $nn, $np, $og, $ng, @ovr) = @ARGV; @ARGV = ();
my %ovr = map { split /=/, $_, 2 } @ovr;
sub i2n { my @o = split /\./, $_[0]; ($o[0] << 24) | ($o[1] << 16) | ($o[2] << 8) | $o[3] }
sub n2i { my $n = $_[0]; join ".", ($n >> 24) & 255, ($n >> 16) & 255, ($n >> 8) & 255, $n & 255 }
my $osz = 2 ** (32 - $op); my $nsz = 2 ** (32 - $np);
my $ob = i2n($on) - (i2n($on) % $osz); my $nb = i2n($nn) - (i2n($nn) % $nsz);
sub map_ip {
  my $ip = shift;
  return $ip if grep { $_ > 255 } split /\./, $ip;
  return $ovr{$ip} if exists $ovr{$ip};
  return $ng if $og ne "" && $ip eq $og;
  my $n = i2n($ip);
  return $ip if $n - ($n % $osz) != $ob;
  my $off = $n - $ob;
  return n2i($nb) if $off == 0;
  return n2i($nb + $nsz - 1) if $off == $osz - 1;
  if ($off >= $nsz - 1) { print STDERR "UNMAPPABLE $ip\n"; return $ip }
  return n2i($nb + $off);
}
while (my $l = <STDIN>) {
  $l =~ s{(?<![\d.])(\d{1,3}(?:\.\d{1,3}){3})(/\d{1,2})?(?!\d|\.\d)}{
    my ($ip, $sfx) = ($1, $2 // "");
    my $m = map_ip($ip);
    $sfx = "/$np" if $m ne $ip && $sfx eq "/$op";
    $m . $sfx
  }ge;
  print $l;
}'

# Plan state (globals): current network and target network.
BRIDGE='' OLD_ADDR='' OLD_PREFIX='' OLD_NET='' OLD_GW=''
NEW_NET='' NEW_PREFIX='' NEW_GW='' OFFER_IP=''
declare -A OVERRIDE=()      # forced old_ip -> new_ip (host conflict fallback)
DHCP_GUESTS=()             # "file|key" guest NICs switched to DHCP
CONFLICTS=()               # "label|old|new" for the operator / the log

remap() { # remap < in > out
  local -a ovr=() k
  for k in "${!OVERRIDE[@]}"; do ovr+=("$k=${OVERRIDE[$k]}"); done
  perl -e "$REMAP_PL" "$OLD_NET" "$OLD_PREFIX" "$NEW_NET" "$NEW_PREFIX" "$OLD_GW" "$NEW_GW" "${ovr[@]}"
}

map_one() { printf '%s\n' "$1" | remap 2>/dev/null; }

# --- reading the current setup ---------------------------------------------

parse_host_net() { # parse_host_net < interfaces -> "iface address prefix gateway"
  awk '
    function m2p(m,   o, i, c, n) { n = split(m, o, "."); c = 0
      for (i = 1; i <= n; i++) while (o[i] > 0) { c += o[i] % 2; o[i] = int(o[i] / 2) }
      return c }
    function flush() { if (cur != "" && gw != "" && addr != "" && !done) { print cur, addr, pfx, gw; done = 1 } }
    /^iface[ \t]/ { flush(); cur = ($3 == "inet") ? $2 : ""; addr = pfx = gw = ""; next }
    /^[ \t]+address[ \t]/ { n = split($2, a, "/"); if (a[1] ~ /^[0-9.]+$/) { addr = a[1]; if (n > 1) pfx = a[2] } }
    /^[ \t]+netmask[ \t]/ { pfx = m2p($2) }
    /^[ \t]+gateway[ \t]/ { if ($2 ~ /^[0-9.]+$/) gw = $2 }
    END { flush() }
  '
}

read_current() {
  local f=$ROOT/etc/network/interfaces line x
  local -a files=("$f")
  [[ -f $f ]] || die "$f not found - is this a Proxmox VE host?"
  for x in "$ROOT"/etc/network/interfaces.d/*; do [[ -f $x ]] && files+=("$x"); done
  line=$(cat "${files[@]}" | parse_host_net)
  [[ -n $line ]] || die "no static IPv4 interface with a gateway in $f (host already on DHCP?)"
  read -r BRIDGE OLD_ADDR OLD_PREFIX OLD_GW <<< "$line"
  [[ -n $OLD_PREFIX ]] || die "could not read the prefix length of $BRIDGE"
  OLD_NET=$(net_of "$OLD_ADDR" "$OLD_PREFIX")
}

list_guest_ips() { # -> "kind id key ip prefix file" for every static guest NIC
  local f kind id
  for f in "$ROOT"/etc/pve/lxc/*.conf "$ROOT"/etc/pve/qemu-server/*.conf; do
    [[ -f $f ]] || continue
    kind=ct; [[ $f == */qemu-server/* ]] && kind=vm
    id=$(basename "$f" .conf)
    awk -v kind="$kind" -v id="$id" -v file="$f" '
      /^\[/ { exit }   # snapshot sections follow the live config
      /^(net|ipconfig)[0-9]+:/ {
        key = $1; sub(":", "", key)
        if (match($0, /ip=[0-9.]+\/[0-9]+/)) {
          v = substr($0, RSTART + 3, RLENGTH - 3); split(v, a, "/")
          print kind, id, key, a[1], a[2], file
        }
      }' "$f"
  done
}

list_vms_without_ipconfig() { # VMs set their IP inside the guest OS: report only
  local f
  for f in "$ROOT"/etc/pve/qemu-server/*.conf; do
    [[ -f $f ]] || continue
    awk '/^\[/ { exit } /^net[0-9]+:/ { n = 1 } /^ipconfig[0-9]+:/ { c = 1 } END { exit !(n && !c) }' "$f" \
      && basename "$f" .conf
  done
}

target_files() { # every host-side file that may hold LAN addresses
  local f
  for f in "$ROOT"/etc/pve/lxc/*.conf "$ROOT"/etc/pve/qemu-server/*.conf \
           "$ROOT"/etc/pve/storage.cfg "$ROOT"/etc/pve/datacenter.cfg \
           "$ROOT"/etc/pve/firewall/*.fw "$ROOT"/etc/pve/nodes/*/host.fw \
           "$ROOT"/etc/resolv.conf "$ROOT"/etc/hosts \
           "$ROOT"/etc/network/interfaces.d/* "$ROOT"/etc/network/interfaces; do
    [[ -f $f && ! -L $f ]] && printf '%s\n' "$f"
  done
  return 0
}

# --- probing the new network -------------------------------------------------

parse_dhcp_offer() { # parse_dhcp_offer < dhcpcd -T output -> "ip prefix gateway"
  local ip='' pfx='' gw='' line k v
  while IFS= read -r line; do
    [[ $line == new_*=* ]] || continue
    k=${line%%=*}; v=${line#*=}; v=${v//\'/}
    case $k in
      new_ip_address) ip=$v ;;
      new_subnet_cidr) pfx=$v ;;
      new_routers) gw=${v%% *} ;;
    esac
  done
  [[ -n $ip && -n $pfx ]] || return 1
  echo "$ip $pfx $gw"
}

probe_dhcp() { # probe_dhcp <seconds> -> "ip prefix gateway"; changes nothing
  # dhcpcd -T stops at the OFFER and only prints it: no lease, no address.
  timeout $(( $1 + 10 )) "$DHCPCD" -4 -T -1 -t "$1" "$BRIDGE" 2>/dev/null | parse_dhcp_offer
}

gateway_reachable() {
  local -a arp
  read -ra arp <<< "$ARPING"
  $PING -c 1 -W 2 "$OLD_GW" >/dev/null 2>&1 && return 0
  "${arp[@]}" -c 2 -w 3 -I "$BRIDGE" "$OLD_GW" >/dev/null 2>&1
}

ip_in_use() { # ARP duplicate-address probe: answers even when ping is firewalled
  local -a arp
  read -ra arp <<< "$ARPING"
  [[ $1 == "$NEW_GW" ]] && return 0
  ! "${arp[@]}" -D -c 2 -w 3 -I "$BRIDGE" "$1" >/dev/null 2>&1
}

set_target() { # set_target <net> <prefix> <gateway>
  NEW_NET=$(net_of "$1" "$2"); NEW_PREFIX=$2; NEW_GW=$3
  is_ip "$NEW_GW" || die "invalid gateway: $NEW_GW"
  in_net "$NEW_GW" "$NEW_NET" "$NEW_PREFIX" || die "gateway $NEW_GW is not inside $NEW_NET/$NEW_PREFIX"
}

same_network() {
  [[ $OLD_NET == "$NEW_NET" && $OLD_PREFIX == "$NEW_PREFIX" && $OLD_GW == "$NEW_GW" ]]
}

# --- planning ----------------------------------------------------------------

# check_conflicts <policy>: policy "auto" resolves on its own (host -> the
# DHCP-offered address, guests -> DHCP); "ask" asks the operator.
check_conflicts() {
  local policy=$1 kind id key ip pfx file new label choice
  local host_new
  host_new=$(map_one "$OLD_ADDR")
  if [[ $host_new == "$NEW_GW" ]] || ! in_net "$host_new" "$NEW_NET" "$NEW_PREFIX" \
     || { [[ $host_new != "$OLD_ADDR" ]] && ip_in_use "$host_new"; }; then
    CONFLICTS+=("host $BRIDGE|$OLD_ADDR|$host_new")
    if [[ $policy == auto ]]; then
      [[ -n $OFFER_IP ]] || die "host address $host_new is taken and there is no DHCP offer to fall back on"
      OVERRIDE[$OLD_ADDR]=$OFFER_IP
      log "host: $host_new is taken, using the DHCP-offered $OFFER_IP instead"
    else
      choice=$(ask "Host address $host_new is already used on the new network. Address to use instead (empty = abort):" "$OFFER_IP") || die "aborted."
      [[ -n $choice ]] || die "aborted."
      is_ip "$choice" && in_net "$choice" "$NEW_NET" "$NEW_PREFIX" || die "$choice is not inside $NEW_NET/$NEW_PREFIX"
      OVERRIDE[$OLD_ADDR]=$choice
    fi
  fi

  while read -r kind id key ip pfx file; do
    [[ -n $ip ]] || continue
    in_net "$ip" "$OLD_NET" "$OLD_PREFIX" || continue   # not on the LAN we are leaving
    new=$(map_one "$ip")
    label="$kind $id $key"
    if [[ $new == "$NEW_GW" ]] || ! in_net "$new" "$NEW_NET" "$NEW_PREFIX" \
       || { [[ $new != "$ip" ]] && ip_in_use "$new"; }; then
      CONFLICTS+=("$label|$ip|$new")
      if [[ $policy == auto ]]; then
        DHCP_GUESTS+=("$file|$key")
        log "$label: $new is taken, switching this NIC to DHCP"
      elif confirm "$label: $new is already used on the new network. Switch this NIC to DHCP?"; then
        DHCP_GUESTS+=("$file|$key")
      else
        confirm "Keep $new anyway (it WILL clash)?" || die "aborted."
      fi
    fi
  done < <(list_guest_ips)
}

set_nic_dhcp() { # set_nic_dhcp <key> < conf > conf: only the live section
  awk -v key="$1" '
    /^\[/ { live = 0 } NR == 1 { live = 1 }
    live && index($0, key ":") == 1 {
      gsub(/ip=[0-9.]+\/[0-9]+/, "ip=dhcp"); gsub(/,gw=[0-9.]+/, ""); gsub(/gw=[0-9.]+,/, "")
    }
    { print }'
}

STAGE=
stage_files() { # build the new version of every target file under $STAGE
  local f out entry file key tmp
  STAGE=$(mktemp -d)
  while IFS= read -r f; do
    out=$STAGE/${f#"$ROOT"}
    mkdir -p "$(dirname "$out")"
    remap < "$f" > "$out" 2>>"$STAGE.unmappable"
  done < <(target_files)
  for entry in "${DHCP_GUESTS[@]}"; do
    file=${entry%|*}; key=${entry#*|}
    out=$STAGE/${file#"$ROOT"}; tmp=$out.tmp
    set_nic_dhcp "$key" < "$out" > "$tmp" && mv "$tmp" "$out"
  done
}

changed_files() { # host paths whose staged version differs
  local f
  while IFS= read -r f; do
    cmp -s "$f" "$STAGE/${f#"$ROOT"}" || printf '%s\n' "$f"
  done < <(target_files)
}

show_plan() {
  local kind id key ip pfx file new state f
  log ""
  log "Network:  $OLD_NET/$OLD_PREFIX gw $OLD_GW  ->  $NEW_NET/$NEW_PREFIX gw $NEW_GW"
  log ""
  new=${OVERRIDE[$OLD_ADDR]:-$(map_one "$OLD_ADDR")}
  printf '  %-22s %-16s -> %s\n' "host $BRIDGE" "$OLD_ADDR" "$new"
  while read -r kind id key ip pfx file; do
    [[ -n $ip ]] || continue
    new=$(map_one "$ip"); state=
    for f in "${DHCP_GUESTS[@]}"; do
      if [[ $f == "$file|$key" ]]; then new=dhcp; state=" (was taken)"; fi
    done
    printf '  %-22s %-16s -> %s%s\n' "$kind $id $key" "$ip" "$new" "$state"
  done < <(list_guest_ips)
  if [[ -s $STAGE.unmappable ]]; then
    log ""
    warn "these addresses do not fit the new subnet and were left as is:"
    sort -u "$STAGE.unmappable" | sed 's/^UNMAPPABLE /  /' >&2
  fi
  log ""
  log "Files that will change:"
  changed_files | sed "s|^$ROOT|  |"
}

show_diffs() {
  local f
  while IFS= read -r f; do
    diff -u --label "${f#"$ROOT"} (now)" --label "${f#"$ROOT"} (new)" "$f" "$STAGE/${f#"$ROOT"}" || true
  done < <(changed_files)
  return 0
}

# --- applying ----------------------------------------------------------------

BACKUP=
apply_files() {
  local f rel
  BACKUP=$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)
  mkdir -p "$BACKUP"
  mapfile -t files < <(changed_files)
  for f in "${files[@]}"; do
    rel=${f#"$ROOT"}
    mkdir -p "$BACKUP/$(dirname "$rel")"
    cp -p "$f" "$BACKUP/$rel"
  done
  # /etc/pve is a FUSE filesystem (pmxcfs): rewrite in place, never mv over it.
  for f in "${files[@]}"; do
    cat "$STAGE/${f#"$ROOT"}" > "$f"
    log "  updated ${f#"$ROOT"}"
  done
  log "Backup of the previous files: ${BACKUP#"$ROOT"}"
}

save_state() { # save_state <post_pending>
  mkdir -p "$(dirname "$STATE_FILE")"
  cat > "$STATE_FILE" <<EOF
OLD_CIDR=$OLD_NET/$OLD_PREFIX
OLD_GW=$OLD_GW
NEW_CIDR=$NEW_NET/$NEW_PREFIX
NEW_GW=$NEW_GW
BACKUP=${BACKUP#"$ROOT"}
POST_PENDING=$1
LAST_RUN=$(now)
EOF
}

state_get() { # state_get <key>  (empty when unknown, never fails)
  [[ -f $STATE_FILE ]] || return 0
  sed -n "s/^$1=//p" "$STATE_FILE" | tail -n 1
}

state_set() { # state_set <key> <value>
  [[ -f $STATE_FILE ]] || return 0
  sed -i "s|^$1=.*|$1=$2|" "$STATE_FILE"
}

# --- after the reboot: tailscale + leftovers ---------------------------------

running_cts() { $PCT list 2>/dev/null | awk 'NR > 1 && $2 == "running" { print $1 }'; }

in_guest() { # in_guest <ct-id|host> <cmd...>
  local where=$1; shift
  if [[ $where == host ]]; then "$@"; else $PCT exec "$where" -- "$@"; fi
}

split_routes() { # split_routes <csv> -> "subnets-csv exit(0|1)"; exit-node routes apart
  local r subnets='' exitnode=0 IFS=,
  for r in $1; do
    case $r in
      0.0.0.0/0|::/0) exitnode=1 ;;
      *) subnets+=${subnets:+,}$r ;;
    esac
  done
  echo "$subnets $exitnode"
}

update_tailscale_routes() {
  local where ts prefs routes subnets exitnode new
  local -a cmd
  for where in host $(running_cts); do
    ts=tailscale; [[ $where == host ]] && ts=$HOST_TAILSCALE
    in_guest "$where" sh -c "command -v $ts" >/dev/null 2>&1 || continue
    prefs=$(in_guest "$where" "$ts" debug prefs 2>/dev/null) || continue
    routes=$(printf '%s' "$prefs" | perl -MJSON::PP -e '
      my $p = eval { decode_json(join "", <STDIN>) } or exit;
      print join ",", @{ $p->{AdvertiseRoutes} || [] }')
    read -r subnets exitnode <<< "$(split_routes "$routes")"
    [[ -n $subnets ]] || continue
    new=$(printf '%s\n' "$subnets" | remap 2>/dev/null)
    [[ $new != "$subnets" ]] || continue
    log "tailscale on $where: advertised subnet $subnets -> $new"
    # 0.0.0.0/0 + ::/0 in the prefs mean "exit node": keep it with the proper flag.
    cmd=("$ts" set --advertise-routes="$new")
    [[ $exitnode == 1 ]] && cmd+=(--advertise-exit-node)
    if [[ $DRY_RUN == 1 ]]; then log "  would run: ${cmd[*]}"; continue; fi
    if in_guest "$where" "${cmd[@]}"; then
      log "  done. Approve the new route in the Tailscale admin console (Machines -> ... -> Edit route settings)."
    else
      warn "tailscale set failed on $where - run: ${cmd[*]}"
    fi
  done
}

leftover_pattern() { # grep -E pattern for "still points at the old LAN"
  local IFS=. o i k pat=
  if [[ $OLD_NET == "$NEW_NET" && $OLD_PREFIX == "$NEW_PREFIX" ]]; then
    # only the gateway moved
    printf '(^|[^0-9.])%s([^0-9]|$)' "${OLD_GW//./\\.}"
    return
  fi
  read -ra o <<< "$OLD_NET"
  k=$(( OLD_PREFIX / 8 ))
  for (( i = 0; i < k; i++ )); do pat+="${o[i]}\\."; done
  printf '(^|[^0-9.])%s[0-9]' "$pat"
}

# Runs inside each guest with plain sh: GNU grep on Debian, BusyBox on Alpine
# (no -I / --exclude-dir there, so binaries are weeded out by hand).
# Skips caches, shell history, man pages and files whose only hits are in
# comments ("# e.g. 192.168.1.1" examples). $1 = pattern, rest = directories.
SCAN_SH='p=$1; shift; ds=; for d in "$@"; do [ -d "$d" ] && ds="$ds $d"; done
[ -n "$ds" ] || exit 0
if grep --version 2>/dev/null | grep -q GNU; then
  grep -rIlE --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=.cache \
    --exclude-dir=site-packages --exclude-dir=man --exclude-dir=pve-renumber-backups \
    --exclude="*_history" --exclude="querylog*" --exclude=pve-renumber-report.txt -e "$p" $ds
else
  grep -rlE -e "$p" $ds \
  | grep -vE "/(\.git|node_modules|\.cache|site-packages|man|pve-renumber-backups)/|_history$|/querylog|pve-renumber-report.txt$" \
  | while IFS= read -r f; do
      [ "$(head -c 8192 "$f" | tr -d "\000" | wc -c)" = "$(head -c 8192 "$f" | wc -c)" ] && echo "$f"
    done
fi | while IFS= read -r f; do
  grep -E -e "$p" "$f" 2>/dev/null | grep -qvE "^[[:space:]]*(#|;|//)" && echo "$f"
done'

scan_leftovers() {
  local pat where hits vm d
  local -a dirs
  pat=$(leftover_pattern)
  log "Files still mentioning the old network ($OLD_NET/$OLD_PREFIX gw $OLD_GW):"
  log "(app configs, .env files, reverse-proxy targets, mounts, DNS rewrites...)"
  for where in host $(running_cts); do
    dirs=()
    for d in $SCAN_DIRS; do
      if [[ $where == host ]]; then dirs+=("$ROOT$d"); else dirs+=("$d"); fi
    done
    # /etc/pve, interfaces, hosts, resolv.conf: rewritten on the host, and
    # regenerated by Proxmox inside containers at every start; /etc/issue is
    # the console banner, regenerated at boot.
    hits=$(in_guest "$where" timeout 120 sh -c "$SCAN_SH" sh "$pat" "${dirs[@]}" 2>/dev/null \
           | sed "s|^$ROOT||" \
           | grep -vE '^/etc/(pve/|network/interfaces|hosts$|resolv.conf$|issue$)' | head -n 50 || true)
    [[ -n $hits ]] || continue
    log ""
    if [[ $where == host ]]; then log "  host:"; else log "  CT $where:"; fi
    printf '%s\n' "$hits" | sed 's/^/    /'
  done
  while IFS= read -r vm; do
    [[ -n $vm ]] && log "  VM $vm: sets its IP inside its own OS - check it from its console."
  done < <(list_vms_without_ipconfig)
  log ""
  log "Databases (e.g. a reverse proxy's proxy hosts) are not scanned: check them in their UI."
}

load_old_from_state() {
  local c
  c=$(parse_cidr "$(state_get OLD_CIDR)") || return 1
  read -r OLD_NET OLD_PREFIX <<< "$c"
  c=$(parse_cidr "$(state_get NEW_CIDR)") || return 1
  read -r NEW_NET NEW_PREFIX <<< "$c"
  OLD_GW=$(state_get OLD_GW)
  NEW_GW=$(state_get NEW_GW)
}

post() {
  [[ $(state_get POST_PENDING) == 1 ]] || { log "pve-renumber: nothing pending."; return 0; }
  load_old_from_state || die "state file is unreadable: $STATE_FILE"
  [[ $DRY_RUN == 1 ]] || sleep "$POST_DELAY"
  update_tailscale_routes
  scan_leftovers | tee "$REPORT_FILE"
  log ""
  log "Report saved to ${REPORT_FILE#"$ROOT"}"
  [[ $DRY_RUN == 1 ]] || state_set POST_PENDING 0
}

# --- modes -------------------------------------------------------------------

preflight() {
  [[ -n $ROOT || $EUID -eq 0 ]] || die "run as root."
  [[ ! -f $ROOT/etc/pve/corosync.conf ]] || die "this host is in a cluster; renumbering corosync is out of scope."
  command -v perl >/dev/null || die "perl not found."
}

check_deps() { # the boot service is useless without these two
  local -a arp
  read -ra arp <<< "$ARPING"
  command -v "$DHCPCD" >/dev/null || warn "dhcpcd not found: the new network cannot be detected (apt install dhcpcd-base)"
  command -v "${arp[0]}" >/dev/null || warn "${arp[0]} not found: taken addresses cannot be detected (apt install busybox)"
  return 0
}

reboot_host() {
  log "Rebooting to apply the new addresses..."
  $SYSTEMCTL reboot --no-block
}

auto() {
  local deadline offer ip pfx gw last
  preflight
  read_current
  if gateway_reachable; then log "pve-renumber: gateway $OLD_GW answers, network unchanged."; return 0; fi

  log "pve-renumber: gateway $OLD_GW does not answer on $BRIDGE, probing the network..."
  deadline=$(( SECONDS + AUTO_WAIT ))
  offer=
  while (( SECONDS < deadline )); do
    gateway_reachable && { log "gateway $OLD_GW answers now, network unchanged."; return 0; }
    offer=$(probe_dhcp 15) && break
    sleep 5
  done
  [[ -n $offer ]] || { log "no gateway and no DHCP offer (cable? box still booting?): leaving the config alone."; return 0; }

  read -r ip pfx gw <<< "$offer"
  [[ -n $gw ]] || { log "DHCP offer without a router: leaving the config alone."; return 0; }
  OFFER_IP=$ip
  set_target "$ip" "$pfx" "$gw"
  if same_network; then
    log "DHCP confirms the configured network ($OLD_NET/$OLD_PREFIX gw $OLD_GW); the gateway is just not answering. Nothing to do."
    return 0
  fi

  last=$(state_get LAST_RUN)
  if [[ -n $last ]] && (( $(now) - last < AUTO_GUARD )); then
    warn "already renumbered $(( $(now) - last ))s ago and the network still looks wrong; not looping. Use the console."
    return 0
  fi

  log "new network: $NEW_NET/$NEW_PREFIX gw $NEW_GW (offered $OFFER_IP)"
  check_conflicts auto
  stage_files
  show_plan
  [[ -n $(changed_files) ]] || { log "nothing to change."; return 0; }
  if [[ $DRY_RUN == 1 ]]; then log ""; log "Dry run: nothing was written."; return 0; fi
  apply_files
  save_state 1
  reboot_host
}

interactive() { # interactive [target-cidr] [gateway]
  local to=$1 gw=$2 offer ip pfx ogw cidr
  preflight
  read_current
  log "Current network: $BRIDGE $OLD_ADDR/$OLD_PREFIX gw $OLD_GW"

  if [[ -n $to ]]; then
    cidr=$(parse_cidr "$to") || die "invalid --to: $to (expected a.b.c.d/nn)"
    read -r ip pfx <<< "$cidr"
    [[ -n $gw ]] || die "--to needs --gw"
    set_target "$ip" "$pfx" "$gw"
  else
    log "Asking the DHCP server of this network what it hands out (nothing is changed)..."
    if offer=$(probe_dhcp 20); then
      read -r ip pfx ogw <<< "$offer"
      OFFER_IP=$ip
      log "DHCP offer: $ip/$pfx, gateway ${ogw:-none}"
      [[ -n $ogw ]] || die "the offer has no gateway; pass --to and --gw."
      set_target "$ip" "$pfx" "$ogw"
    else
      warn "no DHCP answer on $BRIDGE (cable plugged? DHCP off on the box?)."
      cidr=$(ask "New network (a.b.c.d/nn, empty = abort):") || die "no tty; pass --to and --gw."
      [[ -n $cidr ]] || die "aborted."
      cidr=$(parse_cidr "$cidr") || die "invalid network (expected a.b.c.d/nn)"
      read -r ip pfx <<< "$cidr"
      gw=$(ask "New gateway:") || die "aborted."
      set_target "$ip" "$pfx" "$gw"
    fi
  fi

  if same_network; then
    log "This host already matches that network. Nothing to do."
    gateway_reachable && log "Gateway $OLD_GW answers." || warn "gateway $OLD_GW does not answer - check the cable / the box."
    return 0
  fi

  check_conflicts ask
  stage_files
  show_plan
  [[ -n $(changed_files) ]] || { log "nothing to change."; return 0; }
  if confirm "Show the full diff?"; then show_diffs; fi
  if [[ $DRY_RUN == 1 ]]; then log ""; log "Dry run: nothing was written."; return 0; fi

  log ""
  confirm "Apply these changes?" || die "aborted, nothing was written."
  apply_files
  save_state 1
  log ""
  log "After the reboot, guests come back on the new addresses and the boot service"
  log "(if installed) updates Tailscale routes; otherwise run: pve-renumber --post"
  if confirm "Reboot now?"; then reboot_host; else log "Reboot when ready: the new addresses apply at next boot."; fi
}

restore() { # restore <backup-dir>
  local dir=$1 f rel
  [[ -d $dir ]] || die "no such backup: $dir"
  preflight
  log "Restoring from $dir:"
  while IFS= read -r f; do
    rel=${f#"$dir"}
    log "  $rel"
    [[ $DRY_RUN == 1 ]] || cat "$f" > "$ROOT$rel"
  done < <(find "$dir" -type f | sort)
  [[ $DRY_RUN == 1 ]] || state_set POST_PENDING 0
  log "Done. Reboot to apply."
}

status() {
  preflight
  check_deps
  read_current
  log "Host:      $BRIDGE $OLD_ADDR/$OLD_PREFIX gw $OLD_GW"
  if gateway_reachable; then log "Gateway:   answers"; else log "Gateway:   DOES NOT ANSWER"; fi
  local en
  en=$($SYSTEMCTL is-enabled pve-renumber.service 2>/dev/null) || true
  [[ $en == not-found ]] && en=''
  log "Service:   ${en:-not installed (pve-renumber --install)}"
  if [[ -f $STATE_FILE ]]; then
    log "Last move: $(state_get OLD_CIDR) -> $(state_get NEW_CIDR) (backup $(state_get BACKUP), post pending: $(state_get POST_PENDING))"
  fi
}

install_service() {
  local self dest=$ROOT$INSTALL_PATH
  preflight
  check_deps
  self=$(readlink -f "$0" 2>/dev/null || true)
  if [[ ! -f $self || $self == /dev/* || $self == /proc/* ]]; then
    die "--install needs the script saved as a file:
  curl -fsSL $URL -o $INSTALL_PATH && bash $INSTALL_PATH --install"
  fi
  [[ $self == "$dest" ]] || install -m 0755 "$self" "$dest"
  chmod 0755 "$dest"
  cat > "$ROOT/etc/systemd/system/pve-renumber.service" <<EOF
[Unit]
Description=Renumber this Proxmox host and its guests if it boots on a different LAN
Documentation=https://github.com/kipavy/Wiki/blob/main/self-hosting/storage/proxmox-move-network.md
Wants=network-online.target
After=network-online.target pve-cluster.service
Before=pve-guests.service

[Service]
Type=oneshot
ExecStart=$INSTALL_PATH --auto
TimeoutStartSec=600
StandardOutput=append:/var/log/pve-renumber.log
StandardError=append:/var/log/pve-renumber.log

[Install]
WantedBy=multi-user.target
EOF
  cat > "$ROOT/etc/systemd/system/pve-renumber-post.service" <<EOF
[Unit]
Description=After a renumber: update Tailscale routes, report leftover old addresses
After=pve-guests.service

[Service]
Type=oneshot
ExecStart=$INSTALL_PATH --post
StandardOutput=append:/var/log/pve-renumber.log
StandardError=append:/var/log/pve-renumber.log

[Install]
WantedBy=multi-user.target
EOF
  $SYSTEMCTL daemon-reload
  $SYSTEMCTL enable pve-renumber.service pve-renumber-post.service
  log "Installed $INSTALL_PATH and enabled pve-renumber{,-post}.service."
  log "Check it with: pve-renumber --status"
}

uninstall_service() {
  preflight
  $SYSTEMCTL disable pve-renumber.service pve-renumber-post.service 2>/dev/null || true
  rm -f "$ROOT/etc/systemd/system/pve-renumber.service" "$ROOT/etc/systemd/system/pve-renumber-post.service"
  $SYSTEMCTL daemon-reload
  log "Boot services removed ($INSTALL_PATH kept)."
}

usage() {
  cat <<'EOF'
Usage: pve-renumber [option]

Move a standalone Proxmox VE host and all its LXC/VM guests to a new LAN
subnet, keeping every host part (.75 stays .75). Backs up every file it edits.

  (no option)            probe the new network via DHCP, show the plan, ask, apply
  --to NET/NN --gw IP    target this network instead of probing DHCP
  --dry-run              show the plan (and diff) only, write nothing
  --status               current network, gateway check, service state
  --post                 after the reboot: update Tailscale routes, list leftovers
  --scan                 list files that still mention the previous network
  --restore DIR          put back the files saved in a backup directory
  --install              install the boot service (auto-renumber on a new LAN)
  --uninstall            remove the boot service
  --auto                 what the boot service runs (non-interactive)
  -h, --help             this help
EOF
}

main() {
  set -euo pipefail
  local mode=interactive to='' gw='' dir=''
  while (( $# )); do
    case $1 in
      --to) to=${2:?--to needs NET/NN}; shift ;;
      --gw) gw=${2:?--gw needs an address}; shift ;;
      --dry-run) DRY_RUN=1 ;;
      --auto) mode=auto ;;
      --post) mode=post ;;
      --scan) mode=scan ;;
      --status) mode=status ;;
      --restore) mode=restore; dir=${2:?--restore needs a directory}; shift ;;
      --install) mode=install ;;
      --uninstall) mode=uninstall ;;
      -h|--help) usage; return 0 ;;
      *) usage >&2; die "unknown option: $1" ;;
    esac
    shift
  done

  case $mode in
    interactive) interactive "$to" "$gw" ;;
    auto) auto ;;
    post) preflight; post ;;
    scan) preflight; load_old_from_state || die "no previous move recorded in $STATE_FILE"; scan_leftovers ;;
    status) status ;;
    restore) restore "$dir" ;;
    install) install_service ;;
    uninstall) uninstall_service ;;
  esac
}

# Only run when executed, never when sourced by the test harness.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
