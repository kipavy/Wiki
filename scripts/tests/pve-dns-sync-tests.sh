#!/usr/bin/env bash
# Tests for pve-dns-sync.sh, against the same fixture host as pve-renumber.
# Run: bash scripts/tests/pve-dns-sync-tests.sh
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SCRIPT="$HERE/../pve-dns-sync.sh"
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

FAKE=$(mktemp -d)
cat > "$FAKE/pct" <<'EOF'
#!/usr/bin/env bash
# exec <id> -- ip ...  -> the DHCP lease of CT106; exec <id> -- sh -c ... -> run locally
[[ $1 == exec ]] || exit 2
id=$2; shift 3
if [[ $1 == ip ]]; then
  [[ $id == 106 ]] && echo "2: eth0    inet 192.168.1.38/24 brd 192.168.1.255 scope global dynamic eth0"
  exit 0
fi
"$@"
EOF
chmod +x "$FAKE/pct"
export PCT="$FAKE/pct"

# shellcheck source=../pve-dns-sync.sh
source "$SCRIPT"

echo "dns_label / aliases"
assert_eq 'proxmox-backup-server' "$(dns_label 'Proxmox_Backup-Server')" 'lower-case, _ -> -'
assert_eq ' pbs' "$(aliases 'backup;dns-pbs')" 'only dns-* tags become aliases'
assert_eq '' "$(aliases -)" 'no tags'

echo
echo "render_block"
ROOT=$FIX/root DOMAIN=lan
expected="$BEGIN
192.168.1.1 box.lan
192.168.1.38 cloudflared.lan
192.168.1.50 cloudinit-vm.lan
192.168.1.75 pve.lan
192.168.1.76 tailscale.lan
192.168.1.95 alpine-adguard.lan adguard.lan
192.168.1.105 proxmox-backup-server.lan pbs.lan
192.168.1.110 npmplus.lan
192.168.1.149 docker.lan
$END"
assert_eq "$expected" "$(render_block)" \
  'host, box, static CTs, DHCP CT (live lease), cloud-init VM, tag aliases; sorted; snapshot ignored'
ROOT=

echo
echo "APPLY_SH (runs inside the DNS container)"
H=$(mktemp)
printf '127.0.0.1 localhost\n# --- BEGIN PVE ---\n192.168.1.95 alpine-adguard\n# --- END PVE ---\n' > "$H"
orig=$(cat "$H")
block=$(printf '%s\n192.168.1.149 docker.lan\n%s' "$BEGIN" "$END")
assert_eq updated "$(printf '%s\n' "$block" | sh -c "$APPLY_SH" sh "$H" "$BEGIN" "$END")" 'first run writes'
assert_eq "$orig
$block" "$(cat "$H")" 'block appended, PVE block and the rest preserved'
inode=$(ls -i "$H" | awk '{print $1}')
assert_eq unchanged "$(printf '%s\n' "$block" | sh -c "$APPLY_SH" sh "$H" "$BEGIN" "$END")" 'same block: no write'
block2=$(printf '%s\n192.168.0.149 docker.lan\n%s' "$BEGIN" "$END")
assert_eq updated "$(printf '%s\n' "$block2" | sh -c "$APPLY_SH" sh "$H" "$BEGIN" "$END")" 'changed block: write'
assert_eq "$orig
$block2" "$(cat "$H")" 'old block replaced, not duplicated'
assert_eq "$inode" "$(ls -i "$H" | awk '{print $1}')" 'file rewritten in place (AdGuard watches it)'

echo
echo "rewrites"
DOMAIN=lan REWRITES='*.kipavy.fr=npmplus kipavy.fr=npmplus pbs.kipavy.fr=pbs'
assert_eq '*.kipavy.fr 192.168.1.110
kipavy.fr 192.168.1.110
pbs.kipavy.fr 192.168.1.105' \
  "$(ROOT=$FIX/root render_rewrites "$(ROOT=$FIX/root render_block)")" 'answers follow the records (aliases too)'
Y=$(mktemp)
cat > "$Y" <<'EOF'
  safebrowsing_block_host: standard-block.dns.adguard.com
  rewrites:
    - domain: '*.kipavy.fr'
      answer: 192.168.1.110
      enabled: true
    - domain: kipavy.fr
      answer: 192.168.1.110
      enabled: true
    - domain: other.example
      answer: 10.0.0.1
      enabled: true
  safe_fs_patterns:
EOF
yorig=$(cat "$Y")
assert_eq unchanged "$(printf '*.kipavy.fr 192.168.1.110\nkipavy.fr 192.168.1.110\n' | sh -c "$REWRITE_SH" sh "$Y")" \
  'same IPs: unchanged (no AdGuard restart)'
assert_eq "$yorig" "$(cat "$Y")" 'file untouched'
assert_eq changed "$(printf '*.kipavy.fr 192.168.0.110\nkipavy.fr 192.168.0.110\n' | sh -c "$REWRITE_SH" sh "$Y")" \
  'new IPs: changed'
assert_eq "${yorig//192.168.1.110/192.168.0.110}" "$(cat "$Y")" 'only the listed rewrites moved, other.example kept'
REWRITES=''

echo
echo "sync end-to-end (fake pct runs APPLY_SH locally)"
R=$(mktemp -d); cp -R "$FIX/root/." "$R/"; mkdir -p "$R/etc/default"
printf 'DNS_CT=102\nDOMAIN=lan\n' > "$R/etc/default/pve-dns-sync"
H2=$(mktemp); printf '127.0.0.1 localhost\n' > "$H2"
out=$(ROOT=$R HOSTS_FILE=$H2 bash -c "source '$SCRIPT'; HOSTS_FILE='$H2'; main" 2>&1)
assert_eq 'pve-dns-sync: 9 records published to CT 102' "$out" 'reports what it published'
assert_eq '192.168.1.149 docker.lan' "$(grep docker.lan "$H2")" 'record is in the file'
out=$(ROOT=$R bash -c "source '$SCRIPT'; HOSTS_FILE='$H2'; main" 2>&1)
assert_eq "" "$out" "second run is silent (nothing changed)"
rm -f "$R/etc/default/pve-dns-sync"
out=$(ROOT=$R bash "$SCRIPT" 2>&1)
assert_eq 'yes' "$([[ $out == *DNS_CT* ]] && echo yes)" 'missing config is a clear error'
assert_eq 'RC=0' "$(bash "$SCRIPT" --help >/dev/null 2>&1 && echo RC=0 || echo RC=1)" '--help exits 0'

rm -rf "$FAKE" "$R" "$H" "$H2"
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
