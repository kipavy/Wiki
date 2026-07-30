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

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
