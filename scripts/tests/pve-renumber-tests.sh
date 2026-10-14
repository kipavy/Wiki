#!/usr/bin/env bash
# Tests for pve-renumber.sh. No framework: source the script and poke its
# functions, then run whole modes against a copy of a real host's config
# (fixtures/pve-renumber/root) with fake ping/arping/dhcpcd/pct/systemctl.
# Run: bash scripts/tests/pve-renumber-tests.sh
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SCRIPT="$HERE/../pve-renumber.sh"
FIX="$HERE/fixtures/pve-renumber"

PASS=0 FAIL=0

assert_eq() { # expected actual label
  if [[ "$1" == "$2" ]]; then
    PASS=$((PASS + 1)); printf '  ok   %s\n' "$3"
  else
    FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$3"
    printf '         expected: [%s]\n' "$1"
    printf '         actual:   [%s]\n' "$2"
  fi
}

assert_has() { # needle haystack label
  if [[ "$2" == *"$1"* ]]; then
    PASS=$((PASS + 1)); printf '  ok   %s\n' "$3"
  else
    FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$3"
    printf '         missing:  [%s]\n' "$1"
    printf '         in:       [%s]\n' "${2:0:600}"
  fi
}

# --- fakes ---------------------------------------------------------------------

FAKE=$(mktemp -d)
cat > "$FAKE/ping" <<'EOF'
#!/usr/bin/env bash
exit "${FAKE_PING_RC:-1}"
EOF
cat > "$FAKE/arping" <<'EOF'
#!/usr/bin/env bash
# -D <ip>: exit 1 when the ip is in FAKE_TAKEN. Plain mode: like ping.
ip=${!#}
if [[ " $* " == *" -D "* ]]; then
  [[ " ${FAKE_TAKEN:-} " == *" $ip "* ]] && exit 1
  exit 0
fi
exit "${FAKE_PING_RC:-1}"
EOF
cat > "$FAKE/dhcpcd" <<'EOF'
#!/usr/bin/env bash
echo "dhcpcd $*" >> "$FAKE_LOG"
[[ -n ${FAKE_OFFER:-} ]] || exit 1
cat "$FAKE_OFFER"
EOF
cat > "$FAKE/systemctl" <<'EOF'
#!/usr/bin/env bash
echo "systemctl $*" >> "$FAKE_LOG"
[[ $1 == is-enabled ]] && { echo enabled; exit 0; }
exit 0
EOF
cat > "$FAKE/pct" <<'EOF'
#!/usr/bin/env bash
if [[ $1 == list ]]; then
  echo "VMID       Status     Lock         Name"
  for id in ${FAKE_RUNNING:-}; do echo "$id        running                 ct$id"; done
  exit 0
fi
[[ $1 == exec ]] || exit 2
id=$2; shift 3
echo "pct exec $id -- $*" >> "$FAKE_LOG"
case "$*" in
  *"command -v"*) [[ " ${FAKE_TS_CTS:-} " == *" $id "* ]] ;;
  *"debug prefs"*) cat "$FAKE_PREFS" ;;
  *grep*) [[ $id == "${FAKE_SCAN_CT:-}" ]] && echo "/etc/dokploy/app/.env" ; exit 0 ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$FAKE"/*

export FAKE_LOG="$FAKE/log"
export PING="$FAKE/ping" ARPING="$FAKE/arping" DHCPCD="$FAKE/dhcpcd"
export SYSTEMCTL="$FAKE/systemctl" PCT="$FAKE/pct" HOST_TAILSCALE=no-tailscale-on-test-host
export AUTO_WAIT=1 POST_DELAY=0

new_root() { # fresh copy of the fixture host; prints its path
  local r
  r=$(mktemp -d)
  cp -R "$FIX/root/." "$r/"
  mkdir -p "$r/etc/network/interfaces.d" "$r/usr/local/sbin" "$r/etc/systemd/system" \
           "$r/var/lib" "$r/root"
  : > "$FAKE_LOG"
  echo "$r"
}

# Prompts read /dev/tty. Detach from the terminal (setsid) so a test run from an
# interactive shell answers "no" instead of waiting for a keypress.
DETACH=(); command -v setsid >/dev/null && DETACH=(setsid -w)

run() { # run <root> <args…>: execute the script for real against <root>
  local r=$1; shift
  ROOT=$r STATE_FILE=$r/var/lib/pve-renumber/state BACKUP_ROOT=$r/root/pve-renumber-backups \
    REPORT_FILE=$r/root/pve-renumber-report.txt "${DETACH[@]}" bash "$SCRIPT" "$@" < /dev/null 2>&1
}

# shellcheck source=../pve-renumber.sh
source "$SCRIPT"

# --- pure functions ---------------------------------------------------------

echo "remap"
OLD_NET=192.168.1.0 OLD_PREFIX=24 NEW_NET=192.168.0.0 NEW_PREFIX=24 OLD_GW=192.168.1.1 NEW_GW=192.168.0.254
assert_eq 192.168.0.75 "$(map_one 192.168.1.75)" 'host part is kept'
assert_eq 192.168.0.254 "$(map_one 192.168.1.1)" 'old gateway becomes the new gateway (.1 -> .254)'
assert_eq 8.8.8.8 "$(map_one 8.8.8.8)" 'addresses outside the old subnet are untouched'
assert_eq 192.168.10.5 "$(map_one 192.168.10.5)" '192.168.10.x is not 192.168.1.x'
assert_eq 'ip=192.168.0.76/24,gw=192.168.0.254' "$(echo 'ip=192.168.1.76/24,gw=192.168.1.1' | remap)" \
  'lxc net line: ip and gw both move'
assert_eq 'http://192.168.0.149:2283/x' "$(echo 'http://192.168.1.149:2283/x' | remap)" 'url with port'
assert_eq '0.0.0.0/0,::/0,192.168.0.0/24' "$(echo '0.0.0.0/0,::/0,192.168.1.0/24' | remap)" \
  'network address maps to the new network'
assert_eq 'v1.2.192.168.1.5' "$(echo 'v1.2.192.168.1.5' | remap)" 'no match inside a longer dotted string'
assert_eq 'fingerprint 70:1e:98:3c' "$(echo 'fingerprint 70:1e:98:3c' | remap)" 'hex fingerprints untouched'

OLD_NET=192.168.1.0 OLD_PREFIX=24 NEW_NET=10.0.0.0 NEW_PREFIX=16 OLD_GW=192.168.1.1 NEW_GW=10.0.0.1
assert_eq 'address 10.0.0.75/16' "$(echo 'address 192.168.1.75/24' | remap)" 'prefix change updates /24 -> /16'
assert_eq 10.0.255.255 "$(map_one 192.168.1.255)" 'old broadcast -> new broadcast'

OLD_NET=10.0.0.0 OLD_PREFIX=16 NEW_NET=192.168.1.0 NEW_PREFIX=24 OLD_GW=10.0.0.1 NEW_GW=192.168.1.1
assert_eq 10.0.5.20 "$(map_one 10.0.5.20 2>/dev/null)" 'does not fit the smaller subnet: left alone'
assert_eq 'UNMAPPABLE 10.0.5.20' "$(map_one_err() { printf '10.0.5.20\n' | remap 2>&1 >/dev/null; }; map_one_err)" \
  'and is reported on stderr'

OLD_NET=192.168.1.0 OLD_PREFIX=24 NEW_NET=192.168.0.0 NEW_PREFIX=24 OLD_GW=192.168.1.1 NEW_GW=192.168.0.254
OVERRIDE[192.168.1.75]=192.168.0.39
assert_eq '192.168.0.39 pve' "$(echo '192.168.1.75 pve' | remap)" 'override wins over the offset rule'
OVERRIDE=()

echo
echo "parse_host_net"
assert_eq 'vmbr0 192.168.1.75 24 192.168.1.1' \
  "$(parse_host_net < "$FIX/root/etc/network/interfaces")" 'real Proxmox interfaces file'
assert_eq 'vmbr0 10.1.2.3 16 10.1.0.1' \
  "$(printf 'auto vmbr0\niface vmbr0 inet static\n  address 10.1.2.3\n  netmask 255.255.0.0\n  gateway 10.1.0.1\n' | parse_host_net)" \
  'old-style address + netmask'
assert_eq '' \
  "$(printf 'iface vmbr0 inet dhcp\n\nifacevmbr0 inet6 static\n  address fd00::2/64\n  gateway fd00::1\n' | parse_host_net)" \
  'dhcp host and IPv6 stanzas are ignored'

echo
echo "parse_dhcp_offer"
assert_eq '192.168.0.39 24 192.168.0.254' "$(parse_dhcp_offer < "$FIX/offer-freebox.txt")" 'dhcpcd -T output'
assert_eq 'RC=1' "$(echo 'dhcpcd exited' | parse_dhcp_offer >/dev/null && echo RC=0 || echo RC=1)" 'no offer -> failure'

echo
echo "list_guest_ips"
ROOT=$FIX/root
guests=$(list_guest_ips | awk '{print $1, $2, $3, $4}')
assert_eq 'ct 100 net0 192.168.1.76
ct 101 net0 192.168.1.110
ct 102 net0 192.168.1.95
ct 104 net0 192.168.1.149
ct 105 net0 192.168.1.105
vm 200 ipconfig0 192.168.1.50' "$guests" 'static NICs only, snapshot sections skipped, dhcp CT106 skipped'
assert_eq 201 "$(list_vms_without_ipconfig)" 'VM without cloud-init ipconfig is flagged'
ROOT=

echo
echo "set_nic_dhcp"
assert_eq 'net0: name=eth0,bridge=vmbr0,hwaddr=AA,ip=dhcp,type=veth
[snap]
net0: name=eth0,gw=192.168.1.1,ip=192.168.1.76/24' \
  "$(printf 'net0: name=eth0,bridge=vmbr0,gw=192.168.1.1,hwaddr=AA,ip=192.168.1.76/24,type=veth\n[snap]\nnet0: name=eth0,gw=192.168.1.1,ip=192.168.1.76/24\n' | set_nic_dhcp net0)" \
  'live section only, gw removed'
assert_eq 'ipconfig0: ip=dhcp' "$(echo 'ipconfig0: ip=192.168.1.50/24,gw=192.168.1.1' | set_nic_dhcp ipconfig0)" \
  'cloud-init ipconfig'

echo
echo "split_routes / leftover_pattern"
assert_eq '192.168.1.0/24 1' "$(split_routes '0.0.0.0/0,::/0,192.168.1.0/24')" 'exit-node routes split out'
assert_eq ' 0' "$(split_routes '')" 'no routes'
OLD_NET=192.168.1.0 OLD_PREFIX=24 NEW_NET=192.168.0.0 NEW_PREFIX=24 OLD_GW=192.168.1.1
assert_eq '(^|[^0-9.])192\.168\.1\.[0-9]' "$(leftover_pattern)" 'subnet move: match the old /24'
NEW_NET=192.168.1.0
assert_eq '(^|[^0-9.])192\.168\.1\.1([^0-9]|$)' "$(leftover_pattern)" 'gateway-only move: match the old gateway'

# --- whole modes ---------------------------------------------------------------

echo
echo "--auto: gateway answers"
R=$(new_root)
out=$(FAKE_PING_RC=0 run "$R" --auto)
assert_has 'network unchanged' "$out" 'reports nothing to do'
assert_eq '' "$(diff -r "$FIX/root/etc" "$R/etc" | grep -v '^Only in')" 'no file touched'
assert_eq '' "$(grep reboot "$FAKE_LOG")" 'no reboot'

echo
echo "--auto: no gateway, no DHCP offer"
R=$(new_root)
out=$(run "$R" --auto)
assert_has 'leaving the config alone' "$out" 'gives up safely'
assert_eq '' "$(grep reboot "$FAKE_LOG")" 'no reboot'

echo
echo "--auto: DHCP says it is the same network"
R=$(new_root)
out=$(FAKE_OFFER=$FIX/offer-same.txt run "$R" --auto)
assert_has 'Nothing to do' "$out" 'gateway mute but network confirmed'
assert_eq '' "$(grep reboot "$FAKE_LOG")" 'no reboot'

echo
echo "--auto: new network (Freebox-style 192.168.0.0/24 gw .254)"
R=$(new_root)
out=$(FAKE_OFFER=$FIX/offer-freebox.txt run "$R" --auto)
assert_has 'new network: 192.168.0.0/24 gw 192.168.0.254' "$out" 'detects the new network'
assert_has 'address 192.168.0.75/24' "$(cat "$R/etc/network/interfaces")" 'host address moved'
assert_has 'gateway 192.168.0.254' "$(cat "$R/etc/network/interfaces")" 'host gateway moved'
assert_has '192.168.0.75 pve.kipavy.fr pve' "$(cat "$R/etc/hosts")" '/etc/hosts follows'
assert_has 'nameserver 192.168.0.95' "$(cat "$R/etc/resolv.conf")" 'resolv.conf (AdGuard CT) follows'
assert_has 'gw=192.168.0.254,hwaddr=BC:24:11:84:A3:00,ip=192.168.0.76/24' "$(cat "$R/etc/pve/lxc/100.conf")" 'CT100 moved'
assert_has 'ip=192.168.0.149/24' "$(cat "$R/etc/pve/lxc/104.conf")" 'CT104 moved'
assert_has 'http://192.168.0.149:2283' "$(cat "$R/etc/pve/lxc/104.conf")" 'CT104 description follows'
assert_eq "$(cat "$FIX/root/etc/pve/lxc/106.conf")" "$(cat "$R/etc/pve/lxc/106.conf")" 'DHCP CT106 untouched'
assert_has 'server 192.168.0.105' "$(cat "$R/etc/pve/storage.cfg")" 'PBS storage follows CT105'
assert_has 'fingerprint aa:bb:cc:dd:ee' "$(cat "$R/etc/pve/storage.cfg")" 'fingerprint intact'
assert_has 'ipconfig0: ip=192.168.0.50/24,gw=192.168.0.254' "$(cat "$R/etc/pve/qemu-server/200.conf")" 'cloud-init VM moved'
assert_eq "$(cat "$FIX/root/opt/app/.env")" "$(cat "$R/opt/app/.env")" 'app files are never edited'
assert_eq 1 "$(ls "$R/root/pve-renumber-backups" | wc -l | tr -d ' ')" 'one backup directory'
assert_eq "$(cat "$FIX/root/etc/network/interfaces")" \
  "$(cat "$R"/root/pve-renumber-backups/*/etc/network/interfaces)" 'backup holds the original'
assert_has 'POST_PENDING=1' "$(cat "$R/var/lib/pve-renumber/state")" 'post step armed'
assert_has 'OLD_CIDR=192.168.1.0/24' "$(cat "$R/var/lib/pve-renumber/state")" 'old network recorded'
assert_has 'systemctl reboot --no-block' "$(cat "$FAKE_LOG")" 'reboots to apply'

echo
echo "--auto: guard against looping"
: > "$FAKE_LOG"
out=$(FAKE_OFFER=$FIX/offer-freebox.txt run "$R" --auto)   # same root, still "wrong"
assert_has 'Nothing to do' "$out" 'second boot on the new config: offer matches, no-op'
sed -i 's/^LAST_RUN=.*/LAST_RUN=9999999999/' "$R/var/lib/pve-renumber/state"
cp "$R"/root/pve-renumber-backups/*/etc/network/interfaces "$R/etc/network/interfaces"
out=$(FAKE_OFFER=$FIX/offer-freebox.txt NOW=10000000000 run "$R" --auto)
assert_has 'not looping' "$out" 'refuses a second renumber within the guard window'
assert_eq '' "$(grep reboot "$FAKE_LOG")" 'no reboot loop'

echo
echo "--auto: addresses already taken on the new network"
R=$(new_root)
out=$(FAKE_OFFER=$FIX/offer-freebox.txt FAKE_TAKEN='192.168.0.75 192.168.0.110' run "$R" --auto)
assert_has 'address 192.168.0.39/24' "$(cat "$R/etc/network/interfaces")" 'host falls back to the DHCP-offered address'
assert_has '192.168.0.39 pve.kipavy.fr' "$(cat "$R/etc/hosts")" '/etc/hosts uses it too'
assert_has 'ip=dhcp' "$(cat "$R/etc/pve/lxc/101.conf")" 'conflicting CT switched to DHCP'
assert_eq '' "$(grep -E '^net0:.*gw=' "$R/etc/pve/lxc/101.conf")" 'and its gw is dropped'
assert_has 'ip=192.168.0.76/24' "$(cat "$R/etc/pve/lxc/100.conf")" 'non-conflicting CTs keep their host part'

echo
echo "--dry-run --to"
R=$(new_root)
out=$(run "$R" --dry-run --to 10.10.0.0/24 --gw 10.10.0.1)
assert_has 'Network:  192.168.1.0/24 gw 192.168.1.1  ->  10.10.0.0/24 gw 10.10.0.1' "$out" 'shows the move'
assert_has 'ct 100 net0' "$out" 'lists the guests'
assert_has '10.10.0.76' "$out" 'with their new address'
assert_has '/etc/pve/storage.cfg' "$out" 'lists files to change'
assert_has 'Dry run: nothing was written.' "$out" 'says it wrote nothing'
assert_eq '' "$(diff -r "$FIX/root/etc" "$R/etc" | grep -v '^Only in')" 'and really wrote nothing'
out=$(run "$R" --dry-run --to 10.10.0.0/24 --gw 10.20.0.1)
assert_has 'is not inside' "$out" 'gateway outside the target network is refused'
out=$(run "$R" --dry-run --to 10.10.0.0 --gw 10.10.0.1)
assert_has 'invalid --to' "$out" 'malformed --to is refused'

echo
echo "--post"
R=$(new_root)
FAKE_OFFER=$FIX/offer-freebox.txt run "$R" --auto >/dev/null
: > "$FAKE_LOG"
out=$(FAKE_RUNNING='100 104 106' FAKE_TS_CTS=100 FAKE_PREFS=$FIX/tailscale-prefs.json FAKE_SCAN_CT=104 \
      run "$R" --post)
assert_has 'pct exec 100 -- tailscale set --advertise-routes=192.168.0.0/24 --advertise-exit-node' \
  "$(cat "$FAKE_LOG")" 'tailscale subnet route moved, exit node kept'
assert_has 'Approve the new route' "$out" 'tells to approve the route'
assert_has '/opt/app/.env' "$out" 'host leftovers found (real grep)'
assert_has '/opt/app/inline.conf' "$out" 'a trailing comment does not hide a real hit'
assert_eq '' "$(grep -E 'example.conf|\.cache|_history|/etc/issue' <<< "$out")" \
  'comment-only files, caches, shell history and the console banner are skipped'
assert_has 'CT 104:' "$out" 'guest leftovers listed per CT'
assert_has '/etc/dokploy/app/.env' "$out" 'with their paths'
assert_has 'VM 201' "$out" 'VMs without cloud-init are flagged'
assert_has 'POST_PENDING=0' "$(cat "$R/var/lib/pve-renumber/state")" 'post step disarmed'
assert_has '/opt/app/.env' "$(cat "$R/root/pve-renumber-report.txt")" 'report saved'
: > "$FAKE_LOG"
out=$(run "$R" --post)
assert_has 'nothing pending' "$out" 'second --post is a no-op'

echo
echo "--restore"
R=$(new_root)
FAKE_OFFER=$FIX/offer-freebox.txt run "$R" --auto >/dev/null
b=$(ls -d "$R"/root/pve-renumber-backups/*)
out=$(run "$R" --restore "$b")
assert_eq '' "$(diff -r "$FIX/root/etc" "$R/etc" | grep -v '^Only in')" 'every file back to the original'

echo
echo "--install"
R=$(new_root)
out=$(run "$R" --install)
assert_has 'Before=pve-guests.service' "$(cat "$R/etc/systemd/system/pve-renumber.service")" 'runs before guests start'
assert_has 'ExecStart=/usr/local/sbin/pve-renumber --auto' "$(cat "$R/etc/systemd/system/pve-renumber.service")" 'auto mode'
assert_has 'After=pve-guests.service' "$(cat "$R/etc/systemd/system/pve-renumber-post.service")" 'post runs after guests'
assert_eq 'yes' "$([[ -x $R/usr/local/sbin/pve-renumber ]] && echo yes)" 'script installed'
assert_has 'systemctl enable pve-renumber.service pve-renumber-post.service' "$(cat "$FAKE_LOG")" 'units enabled'

echo
echo "guards"
R=$(new_root)
touch "$R/etc/pve/corosync.conf"
out=$(run "$R" --dry-run --to 10.10.0.0/24 --gw 10.10.0.1)
assert_has 'cluster' "$out" 'refuses a clustered host'
assert_eq 'RC=0' "$(bash "$SCRIPT" --help >/dev/null 2>&1 && echo RC=0 || echo RC=1)" '--help exits 0'
assert_eq 'RC=1' "$(bash "$SCRIPT" --bogus >/dev/null 2>&1 && echo RC=0 || echo RC=1)" 'unknown flag exits non-zero'
# The script must never edit files inside guests: the only commands it sends
# through pct exec are tailscale and the read-only grep scan.
assert_eq '' \
  "$(grep -nE 'in_guest "\$where"' "$SCRIPT" | grep -vE '"\$ts"|command -v|SCAN_SH|cmd\[@\]' || true)" \
  'pct exec is only used for tailscale and the read-only scan'

rm -rf "$FAKE"
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
