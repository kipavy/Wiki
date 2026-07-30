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
#
# NOTE: `script -qec CMD` runs CMD under $SHELL, which is NOT necessarily bash.
# Every probe therefore writes its snippet to a file and runs it with an
# explicit `bash`, otherwise these tests silently exercise the wrong shell
# (zsh accepts `read -r` but not `read -rn1`, and indexes arrays from 1).
in_pty() { # in_pty <input> <bash-snippet> -> raw output, CR stripped
  local input=$1 snippet=$2 tmp
  tmp=$(mktemp)
  printf '%s\n' "$snippet" > "$tmp"
  script -qec "bash '$tmp'" /dev/null <<<"$input" 2>/dev/null | tr -d '\r'
  rm -f "$tmp"
}

tty_answer() { # answer function-call...
  local answer=$1; shift
  in_pty "$answer" "source '$SCRIPT'
$* && echo RC=0 || echo RC=1" | grep -o 'RC=[01]' | tail -1
}

tty_stdout() { # answer function-call... -> the call's stdout only
  local answer=$1; shift
  local out; out=$(mktemp)
  in_pty "$answer" "source '$SCRIPT'
$* > '$out' 2>/dev/null" >/dev/null
  cat "$out"; rm -f "$out"
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
  local tmp; tmp=$(mktemp)
  printf "printf 'y\\ny\\ny\\n' | bash -c \"source '%s'; confirm 'proceed?' && echo RC=0 || echo RC=1\"\n" "$1" > "$tmp"
  script -qec "bash '$tmp'" /dev/null </dev/null 2>/dev/null | tr -d '\r' | grep -o 'RC=[01]' | tail -1
  rm -f "$tmp"
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

echo
echo "select_menu (arrow keys via pty; index on stdout, UI on /dev/tty)"
menu_probe() { # menu_probe <keys> -> the index the menu wrote to stdout
  tty_stdout "$1" "select_menu 'Pick:' alpha beta gamma"
}
assert_eq '0' "$(menu_probe "$(printf '\n')")"             'enter picks the first item'
assert_eq '1' "$(menu_probe "$(printf '\033[B\n')")"       'down arrow then enter picks second'
assert_eq '2' "$(menu_probe "$(printf '\033[B\033[B\n')")" 'two downs pick third'
assert_eq '1' "$(menu_probe "$(printf 'j\n')")"            'j moves down'
assert_eq '0' "$(menu_probe "$(printf 'jk\n')")"           'j then k returns to first'
assert_eq '0' "$(menu_probe "$(printf '\033[A\n')")"       'up at the top does not wrap'
assert_eq '2' "$(menu_probe "$(printf '\033[B\033[B\033[B\n')")" 'down past the end does not wrap'
assert_eq '' "$(menu_probe q)"                             'q cancels with empty stdout'
assert_eq 'RC=1' "$(tty_answer q "select_menu 'Pick:' a b >/dev/null")" \
  'q returns non-zero so callers can abort'

echo
echo "select_menu_numbered fallback"
assert_eq '1' "$(tty_stdout 1 "select_menu_numbered 'Pick:' alpha beta gamma")" \
  'numbered fallback returns the typed index'
assert_eq 'RC=1' "$(tty_answer q "select_menu_numbered 'Pick:' a b >/dev/null")" \
  'numbered fallback cancels on q'
assert_eq 'RC=1' "$(tty_answer 9 "select_menu_numbered 'Pick:' a b >/dev/null")" \
  'numbered fallback rejects out-of-range'

echo
echo "candidate exclusion (aliases and boot disk)"
# Build a fake /dev/disk/by-id: two pool members (each with wwn- AND ata- alias
# pointing at the same fake block file), the boot disk, and one free disk.
BYID_TMP=$(mktemp -d)
DEV_TMP=$(mktemp -d)
: > "$DEV_TMP/diskA"; : > "$DEV_TMP/diskB"; : > "$DEV_TMP/bootssd"; : > "$DEV_TMP/spare"
ln -s "$DEV_TMP/diskA"   "$BYID_TMP/wwn-0x5000c500c2f8832c"
ln -s "$DEV_TMP/diskA"   "$BYID_TMP/ata-ST3000DM008_AAAA"
ln -s "$DEV_TMP/diskB"   "$BYID_TMP/wwn-0x5000c500c2f8832d"
ln -s "$DEV_TMP/bootssd" "$BYID_TMP/ata-SAMSUNG_SSD_BOOT1"
ln -s "$DEV_TMP/spare"   "$BYID_TMP/ata-ST4000VN006_SPARE9"
ln -s "$DEV_TMP/spare"   "$BYID_TMP/wwn-0x5000c500c2f8839f"
ln -s "$DEV_TMP/diskA"   "$BYID_TMP/wwn-0x5000c500c2f8832c-part1"

cand_env() {
  BYID="$BYID_TMP" ZPOOL="$FB/zpool" FAKE_FIXTURE="$FIX/degraded-faulted.txt" FAKE_POOLS=tank \
  FINDMNT="$FB/findmnt" FAKE_ROOT_SRC="$DEV_TMP/bootssd" LSBLK="$FB/lsblk" \
  BLKID="$FB/blkid" ZDB="$FB/zdb" BLOCKDEV="$FB/blockdev" SMARTCTL="$FB/smartctl" \
  FAKE_DISK_STATE=blank FAKE_SIZE=4000787030016 FAKE_SERIAL=SPARE9 \
  FAKE_LSBLK_DISK_PASSTHROUGH=1 "$@"
}
CANDS=$(cand_env bash -c "source '$SCRIPT'; list_candidates" 2>/dev/null)
assert_eq '1' "$(printf '%s\n' "$CANDS" | grep -c . )" \
  'only the one free disk is offered'
assert_eq 'ata-ST4000VN006_SPARE9' "$(printf '%s\n' "$CANDS" | cut -d'|' -f1)" \
  'descriptive ata- alias preferred over wwn- for the same disk'
assert_eq '' "$(printf '%s\n' "$CANDS" | grep -E 'ata-ST3000DM008_AAAA|wwn-0x5000c500c2f8832c' || true)" \
  'the healthy pool member is excluded via BOTH its aliases'
assert_eq '' "$(printf '%s\n' "$CANDS" | grep 'BOOT1' || true)" \
  'the boot disk is never offered as a replacement'
assert_eq '' "$(printf '%s\n' "$CANDS" | grep -- '-part' || true)" \
  'partition aliases are skipped'

echo
echo "choose_candidate: newly-appeared disk is flagged and offered first"
# Two free disks. The pre-swap snapshot contains only diskC, so diskD is the
# one that "appeared" during the swap and must sort first with a NEW marker.
BYID2=$(mktemp -d); DEV2=$(mktemp -d)
: > "$DEV2/diskC"; : > "$DEV2/diskD"; : > "$DEV2/boot2"
ln -s "$DEV2/diskC" "$BYID2/ata-AAA_OLDSPARE"
ln -s "$DEV2/diskD" "$BYID2/ata-ZZZ_JUSTPLUGGED"
ln -s "$DEV2/boot2" "$BYID2/ata-BOOT_DISK2"
cand2_snippet() { cat <<SNIP
source '$SCRIPT'
export BYID='$BYID2' ZPOOL='$FB/zpool' FAKE_FIXTURE='$FIX/healthy-mirror.txt' FAKE_POOLS=tank
export FINDMNT='$FB/findmnt' FAKE_ROOT_SRC='$DEV2/boot2' LSBLK='$FB/lsblk'
export BLKID='$FB/blkid' ZDB='$FB/zdb' BLOCKDEV='$FB/blockdev' SMARTCTL='$FB/smartctl'
export FAKE_DISK_STATE=blank FAKE_SIZE=4000787030016 FAKE_SERIAL=SER123
choose_candidate 3000592982016 '$DEV2/diskC' > '$1' 2>/dev/null
SNIP
}
CC_OUT=$(mktemp)
CC_UI=$(in_pty "$(printf '\n')" "$(cand2_snippet "$CC_OUT")")
assert_eq 'ata-ZZZ_JUSTPLUGGED' "$(cut -d'|' -f1 "$CC_OUT")" \
  'enter selects the newly-appeared disk because it is listed first'
assert_eq 'tagged' \
  "$(grep -q 'appeared just now' <<<"$CC_UI" && echo tagged || echo untagged)" \
  'the new disk carries an "appeared just now" marker'
assert_eq 'once' \
  "$(c=$(grep -o 'appeared just now' <<<"$CC_UI" | head -1 | wc -l); [[ $c -eq 1 ]] && echo once || echo "x$c")" \
  'only the genuinely new disk is marked'
assert_eq '' "$(grep 'BOOT_DISK2' <<<"$CC_UI" || true)" \
  'the boot disk is absent from the replacement menu'
rm -f "$CC_OUT"; rm -rf "$BYID2" "$DEV2"

echo
echo "resilver detection"
assert_eq 'RC=0' "$(ZPOOL="$FB/zpool" FAKE_FIXTURE="$FIX/resilvering.txt" \
  bash -c "source '$SCRIPT'; ZPOOL='$FB/zpool' FAKE_FIXTURE='$FIX/resilvering.txt' resilver_active tank" \
  && echo RC=0 || echo RC=1)" \
  'resilver in progress is detected'
assert_eq 'RC=1' "$(bash -c "source '$SCRIPT'; ZPOOL='$FB/zpool' FAKE_FIXTURE='$FIX/healthy-mirror.txt' resilver_active tank" \
  && echo RC=0 || echo RC=1)" \
  'healthy pool has no resilver'
assert_eq '984G resilvered, 35.42% done, 01:41:12 to go' \
  "$(bash -c "source '$SCRIPT'; ZPOOL='$FB/zpool' FAKE_FIXTURE='$FIX/resilvering.txt' resilver_progress tank")" \
  'progress line is extracted'

echo
echo "command sequences (dry-run)"
# The dead path is offline-then-replace, in that order, with the hardware swap
# and the replacement choice sitting in between (see main).
assert_eq '> zpool offline tank OLD
> zpool replace tank OLD NEW' \
  "$({ DRY_RUN=1 ZPOOL=zpool offline_dead_disk tank OLD; DRY_RUN=1 ZPOOL=zpool apply_replace tank OLD NEW; } | grep '^> ')" \
  'dead path: offline then replace'
assert_eq '> zpool replace tank OLD NEW' \
  "$({ DRY_RUN=1 ZPOOL=zpool explain_dying_path; DRY_RUN=1 ZPOOL=zpool apply_replace tank OLD NEW; } | grep '^> ')" \
  'dying path: replace only, never offline'
assert_eq '' \
  "$(DRY_RUN=1 ZPOOL=zpool explain_dying_path | grep '^> ' || true)" \
  'the dying path emits no command of its own'
assert_eq '' \
  "$({ DRY_RUN=1 ZPOOL=zpool offline_dead_disk tank OLD; DRY_RUN=1 ZPOOL=zpool explain_dying_path; \
       DRY_RUN=1 ZPOOL=zpool apply_replace tank OLD NEW; } \
     | grep -E 'detach|remove|destroy|wipefs|sgdisk|dd ' || true)" \
  'neither path ever emits a destructive command'
# main must offline BEFORE prompting for the swap, and choose the disk after.
assert_eq 'offline<swap<choose' \
  "$(awk '/offline_dead_disk "\$pool"/ { o = NR } /press_enter "Press Enter once/ { s = NR } /chosen=\$\(choose_candidate/ { c = NR } END { print (o && s && c && o < s && s < c) ? "offline<swap<choose" : "WRONG ORDER: " o " " s " " c }' "$SCRIPT")" \
  'main sequences offline, then physical swap, then replacement choice'
# Scan for real invocations, not the comments and help text that name these
# commands as things the script deliberately never runs. Strip comments and the
# usage heredoc first, then look at what is left.
code_only() {
  sed 's/#.*//' "$SCRIPT" \
    | awk '/<<'"'"'EOF'"'"'/ { skip = 1; next } skip && /^EOF$/ { skip = 0; next } !skip'
}
assert_eq '' \
  "$(code_only | grep -nE '(\$ZPOOL"?|zpool) +(detach|remove|destroy)|\b(wipefs|sgdisk|mkfs)\b' || true)" \
  'the script source invokes no destructive command anywhere'
# Guard the guard: the scan must actually be looking at the code.
assert_eq 'found' \
  "$(code_only | grep -qE '\$ZPOOL" replace' && echo found || echo missing)" \
  'source scan does reach the real zpool replace call (scan is not vacuous)'

echo
echo "--help and arg parsing"
assert_eq 'RC=0' "$(bash "$SCRIPT" --help >/dev/null 2>&1 && echo RC=0 || echo RC=1)" \
  '--help exits 0'
assert_eq 'RC=1' "$(bash "$SCRIPT" --bogus-flag >/dev/null 2>&1 && echo RC=0 || echo RC=1)" \
  'unknown flag exits non-zero'
assert_eq 'RC=1' "$(DRY_RUN=1 ZPOOL=/nonexistent/zpool bash "$SCRIPT" --dry-run >/dev/null 2>&1 && echo RC=0 || echo RC=1)" \
  'missing zpool is reported, not crashed through'

rm -rf "$BYID_TMP" "$DEV_TMP"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
