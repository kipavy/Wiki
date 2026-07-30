#!/usr/bin/env bash
# Unit tests for zfs-replace-disk.sh. No framework: source the script and poke
# its functions. Run: bash scripts/tests/run-tests.sh
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SCRIPT="$HERE/../zfs-replace-disk.sh"
FIX="$HERE/fixtures"

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

# shellcheck source=../zfs-replace-disk.sh
source "$SCRIPT"

echo "parse_vdev_leaves"
assert_eq \
  'wwn-0x5000c500c2f8832c|ONLINE|0|0|0|
wwn-0x5000c500c2f8832d|ONLINE|0|0|0|' \
  "$(parse_vdev_leaves tank < "$FIX/healthy-mirror.txt")" \
  'healthy mirror: 2 leaves, no containers'

assert_eq \
  'wwn-0x5000c500c2f8832c|ONLINE|0|0|0|
wwn-0x5000c500c2f8832d|FAULTED|6|98|0|too many errors' \
  "$(parse_vdev_leaves tank < "$FIX/degraded-faulted.txt")" \
  'faulted leaf keeps error counts and note'

assert_eq \
  '9823741982374198237|UNAVAIL|0|0|0|was /dev/disk/by-id/wwn-0x5000c500c2f8832d' \
  "$(parse_vdev_leaves tank < "$FIX/degraded-unavail.txt" | grep UNAVAIL)" \
  'missing disk shows as GUID leaf with was-path note'

assert_eq 3 \
  "$(parse_vdev_leaves tank < "$FIX/resilvering.txt" | wc -l | tr -d ' ')" \
  'resilvering: replacing-1 container excluded, both children kept'

assert_eq 'wwn-0x5000c500c2f8839f|ONLINE|0|0|0|(resilvering)' \
  "$(parse_vdev_leaves tank < "$FIX/resilvering.txt" | grep 9f)" \
  'resilvering child keeps its (resilvering) note'

assert_eq 4 \
  "$(parse_vdev_leaves tank < "$FIX/raidz2-degraded.txt" | wc -l | tr -d ' ')" \
  'raidz2: 4 leaves, raidz2-0 container excluded'

assert_eq '' \
  "$(parse_vdev_leaves tank < "$FIX/degraded-faulted.txt" | grep -E '^(tank|mirror-0)\|' || true)" \
  'pool row and mirror row are never emitted as leaves'

echo
echo "classify_leaf"
assert_eq dead    "$(classify_leaf FAULTED  6 98 0 '0:0:0:UNKNOWN')" 'FAULTED is dead'
assert_eq dead    "$(classify_leaf UNAVAIL  0 0  0 '0:0:0:UNKNOWN')" 'UNAVAIL is dead'
assert_eq dead    "$(classify_leaf REMOVED  0 0  0 '0:0:0:UNKNOWN')" 'REMOVED is dead'
assert_eq dead    "$(classify_leaf OFFLINE  0 0  0 '0:0:0:UNKNOWN')" 'OFFLINE is dead'
assert_eq healthy "$(classify_leaf ONLINE   0 0  0 '0:0:0:PASSED')"  'clean ONLINE is healthy'
assert_eq dying   "$(classify_leaf ONLINE   0 0  4 '0:0:0:PASSED')"  'cksum errors alone mean dying'
assert_eq dying   "$(classify_leaf ONLINE   2 0  0 '0:0:0:PASSED')"  'read errors alone mean dying'
assert_eq dying   "$(classify_leaf ONLINE   0 0  0 '118:0:0:PASSED')" 'reallocated sectors mean dying'
assert_eq dying   "$(classify_leaf ONLINE   0 0  0 '0:3:0:PASSED')"  'pending sectors mean dying'
assert_eq dying   "$(classify_leaf ONLINE   0 0  0 '0:0:0:FAILED')"  'SMART overall FAILED means dying'
assert_eq dying   "$(classify_leaf DEGRADED 0 0  0 '0:0:0:PASSED')"  'DEGRADED leaf is dying, not dead'

echo
echo "smart_signals"
export FAKE_SMART_MODE=healthy
assert_eq '0:0:0:PASSED' "$(SMARTCTL="$HERE/fake-bin/smartctl" smart_signals /dev/disk/by-id/fake)" \
  'healthy disk reports zero counts'
export FAKE_SMART_MODE=dying
assert_eq '118:3:2:PASSED' "$(SMARTCTL="$HERE/fake-bin/smartctl" smart_signals /dev/disk/by-id/fake)" \
  'dying disk reports reallocated/pending/uncorrect counts'
export FAKE_SMART_MODE=failing
assert_eq '0:0:0:FAILED' "$(SMARTCTL="$HERE/fake-bin/smartctl" smart_signals /dev/disk/by-id/fake)" \
  'overall-health FAILED is captured'
unset FAKE_SMART_MODE
assert_eq '0:0:0:UNKNOWN' "$(SMARTCTL=/nonexistent/smartctl smart_signals /dev/disk/by-id/fake)" \
  'missing smartctl degrades to UNKNOWN instead of failing'

echo
echo "confirm (reads /dev/tty, not stdin)"
# `script` gives the function a real tty whose input we control.
tty_answer() { # answer function-call...
  local answer=$1; shift
  script -qec "cd '$HERE'; source '$SCRIPT'; $* && echo RC=0 || echo RC=1" /dev/null \
    <<<"$answer" 2>/dev/null | tr -d '\r' | grep -o 'RC=[01]' | tail -1
}
assert_eq 'RC=0' "$(tty_answer y  'confirm "proceed?"')"  'y accepts'
assert_eq 'RC=0' "$(tty_answer Y  'confirm "proceed?"')"  'Y accepts'
assert_eq 'RC=1' "$(tty_answer '' 'confirm "proceed?"')"  'bare Enter declines (N is default)'
assert_eq 'RC=1' "$(tty_answer n  'confirm "proceed?"')"  'n declines'
assert_eq 'RC=1' "$(tty_answer yes 'confirm "proceed?"')" 'yes is not y — declines'

echo
echo "confirm does not read stdin (the curl|bash bug)"
# Model `curl … | bash` exactly: the inner process's STDIN is a pipe full of
# "y" (as if fed the script's own source text), while /dev/tty is a real pty
# with no pending input (as if the operator is sitting there, silent).
# A correct confirm() reads the tty and gets nothing -> RC=1.
# A naive confirm() reads stdin, eats a "y", and self-approves -> RC=0.
stdin_pipe_probe() { # stdin_pipe_probe <file-to-source>
  script -qec "printf 'y\ny\ny\n' | bash -c \"source '$1'; confirm 'proceed?' && echo RC=0 || echo RC=1\"" \
    /dev/null </dev/null 2>/dev/null | tr -d '\r' | grep -o 'RC=[01]' | tail -1
}
assert_eq 'RC=1' "$(stdin_pipe_probe "$SCRIPT")" \
  'stdin full of y cannot answer a /dev/tty prompt'

# Guard the guard: a deliberately naive confirm() MUST fail the check above,
# otherwise the test proves nothing.
MUTANT=$(mktemp)
cat > "$MUTANT" <<'MUT'
confirm() { local reply=; printf '%s [y/N] ' "$1"; IFS= read -r reply; [[ $reply == y || $reply == Y ]]; }
MUT
assert_eq 'RC=0' "$(stdin_pipe_probe "$MUTANT")" \
  'mutation check: a stdin-reading confirm() does self-approve (test has teeth)'
rm -f "$MUTANT"

echo
echo "confirm_word"
assert_eq 'RC=0' "$(tty_answer WIPE  'confirm_word WIPE "type WIPE"')" 'exact word accepts'
assert_eq 'RC=1' "$(tty_answer wipe  'confirm_word WIPE "type WIPE"')" 'wrong case declines'
assert_eq 'RC=1' "$(tty_answer y     'confirm_word WIPE "type WIPE"')" 'y does not satisfy confirm_word'

echo
echo "run_cmd dry-run"
assert_eq '> touch /tmp/zfs-test-should-not-exist' \
  "$(rm -f /tmp/zfs-test-should-not-exist; DRY_RUN=1 run_cmd touch /tmp/zfs-test-should-not-exist)" \
  'dry-run prints the command'
assert_eq 'absent' \
  "$([[ -e /tmp/zfs-test-should-not-exist ]] && echo present || echo absent)" \
  'dry-run executes nothing'

echo
echo "check_pool_actionable"
assert_eq 'RC=0' "$(FORCE=0 check_pool_actionable tank DEGRADED >/dev/null 2>&1 && echo RC=0 || echo RC=1)" \
  'DEGRADED pool is actionable'
assert_eq 'RC=1' "$(FORCE=0 check_pool_actionable tank ONLINE >/dev/null 2>&1 && echo RC=0 || echo RC=1)" \
  'healthy pool is refused without --force'
assert_eq 'RC=0' "$(FORCE=1 check_pool_actionable tank ONLINE >/dev/null 2>&1 && echo RC=0 || echo RC=1)" \
  'healthy pool allowed with FORCE=1'

echo
echo "disk facts"
FB="$HERE/fake-bin"
assert_eq 'ZAD1234' \
  "$(SMARTCTL="$FB/smartctl" FAKE_SERIAL=ZAD1234 disk_serial /dev/disk/by-id/fake)" \
  'serial comes from smartctl -i'
assert_eq 'unknown' \
  "$(SMARTCTL=/nonexistent/smartctl disk_serial /dev/disk/by-id/fake)" \
  'serial degrades to unknown'
assert_eq '3000592982016' \
  "$(BLOCKDEV="$FB/blockdev" FAKE_SIZE=3000592982016 disk_size /dev/disk/by-id/fake)" \
  'size in bytes from blockdev'
assert_eq '0' \
  "$(BLOCKDEV=/nonexistent/blockdev disk_size /dev/disk/by-id/fake)" \
  'unreadable size is 0'
assert_eq '2.7T' "$(human_size 3000592982016)" 'human_size formats terabytes'
assert_eq '512G' "$(human_size 549755813888)"  'human_size formats gigabytes'

echo
echo "disk_has_data"
assert_eq 'RC=0' "$(FAKE_DISK_STATE=partitioned BLKID="$FB/blkid" LSBLK="$FB/lsblk" ZDB="$FB/zdb" \
  disk_has_data /dev/disk/by-id/fake >/dev/null 2>&1 && echo RC=0 || echo RC=1)" \
  'partitioned disk has data'
assert_eq 'RC=0' "$(FAKE_DISK_STATE=zfs_label BLKID="$FB/blkid" LSBLK="$FB/lsblk" ZDB="$FB/zdb" \
  disk_has_data /dev/disk/by-id/fake >/dev/null 2>&1 && echo RC=0 || echo RC=1)" \
  'old ZFS label counts as data'
assert_eq 'RC=1' "$(FAKE_DISK_STATE=blank BLKID="$FB/blkid" LSBLK="$FB/lsblk" ZDB="$FB/zdb" \
  disk_has_data /dev/disk/by-id/fake >/dev/null 2>&1 && echo RC=0 || echo RC=1)" \
  'blank disk has no data'

echo
echo "validate_replacement"
assert_eq 'RC=1' "$(FAKE_DISK_STATE=blank FAKE_SIZE=1000000000000 \
  BLOCKDEV="$FB/blockdev" BLKID="$FB/blkid" LSBLK="$FB/lsblk" ZDB="$FB/zdb" \
  validate_replacement /dev/disk/by-id/fake 3000592982016 >/dev/null 2>&1 && echo RC=0 || echo RC=1)" \
  'smaller replacement is rejected'
assert_eq 'RC=0' "$(FAKE_DISK_STATE=blank FAKE_SIZE=3000592982016 \
  BLOCKDEV="$FB/blockdev" BLKID="$FB/blkid" LSBLK="$FB/lsblk" ZDB="$FB/zdb" \
  validate_replacement /dev/disk/by-id/fake 3000592982016 >/dev/null 2>&1 && echo RC=0 || echo RC=1)" \
  'same-size blank replacement is accepted'
assert_eq 'RC=0' "$(FAKE_DISK_STATE=blank FAKE_SIZE=4000787030016 \
  BLOCKDEV="$FB/blockdev" BLKID="$FB/blkid" LSBLK="$FB/lsblk" ZDB="$FB/zdb" \
  validate_replacement /dev/disk/by-id/fake 3000592982016 >/dev/null 2>&1 && echo RC=0 || echo RC=1)" \
  'larger blank replacement is accepted'
assert_eq 'RC=1' "$(BLOCKDEV=/nonexistent/blockdev BLKID="$FB/blkid" LSBLK="$FB/lsblk" ZDB="$FB/zdb" \
  validate_replacement /dev/disk/by-id/fake 3000592982016 >/dev/null 2>&1 && echo RC=0 || echo RC=1)" \
  'unreadable replacement size is rejected'
# A disk with data needs the literal word WIPE, not a y/N.
assert_eq 'RC=1' "$(tty_answer y "FAKE_DISK_STATE=partitioned FAKE_SIZE=3000592982016 \
  BLOCKDEV='$FB/blockdev' BLKID='$FB/blkid' LSBLK='$FB/lsblk' ZDB='$FB/zdb' \
  validate_replacement /dev/disk/by-id/fake 3000592982016 >/dev/null 2>&1")" \
  'disk with data: y is not enough'
assert_eq 'RC=0' "$(tty_answer WIPE "FAKE_DISK_STATE=partitioned FAKE_SIZE=3000592982016 \
  BLOCKDEV='$FB/blockdev' BLKID='$FB/blkid' LSBLK='$FB/lsblk' ZDB='$FB/zdb' \
  validate_replacement /dev/disk/by-id/fake 3000592982016 >/dev/null 2>&1")" \
  'disk with data: WIPE proceeds'

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
