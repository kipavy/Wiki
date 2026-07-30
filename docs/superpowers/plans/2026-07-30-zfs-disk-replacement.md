# ZFS Disk Replacement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Document the "my HDD is dead" recovery procedure in the wiki and ship an interactive `zfs-replace-disk.sh` that walks the operator through it safely.

**Architecture:** One self-contained bash script (it must be runnable via `bash <(curl -sL …)`, so it cannot source external libraries). All external commands are called through overridable variables (`ZPOOL`, `SMARTCTL`, `BLOCKDEV`, `LSBLK`, `BLKID`, `ZDB`) so tests can substitute fakes. `main` runs only when the file is executed, not when sourced, which lets a plain-bash test harness source the script and unit-test its parsing and classification functions against captured `zpool status` fixtures. The wiki section is written to stand alone without the script.

**Tech Stack:** bash 4+, awk, OpenZFS 2.2/2.3 (`zpool`), `smartmontools`, `util-linux` (`blockdev`, `lsblk`, `blkid`). No test framework dependency — a plain bash assert harness, because the repo is markdown-only today and must not grow an install step.

## Global Constraints

- Target environment is fixed: Proxmox VE on a **single ext4/LVM SSD**, plus **2 HDDs in a ZFS mirror of whole disks** addressed by `/dev/disk/by-id/`. Pool name in all examples: `tank`.
- The pool contains **no boot or root members**. Nothing in this work touches partition tables, ESPs, or `proxmox-boot-tool`.
- `scripts/zfs-replace-disk.sh` must remain a **single file with zero runtime dependencies on other repo files**.
- Every operator prompt reads from **`/dev/tty`**, never stdin.
- **`N` is the default** on every `y/N` prompt (bare Enter declines).
- The script **never** runs `zpool detach`, `zpool remove`, `zpool destroy`, `wipefs`, `dd`, or `sgdisk`.
- Parse `zpool status` **text**; do not use `zpool status -j` (too new for shipped Proxmox).
- Documented invocation is the raw GitHub URL, no shortener:
  `bash <(curl -sL https://raw.githubusercontent.com/kipavy/Wiki/main/scripts/zfs-replace-disk.sh)`
- Wiki prose follows the existing page style: `### `/`#### ` headings, ` ```shellscript ` code fences, GitBook `{% hint %}` blocks.
- Commit messages follow the repo's existing convention, e.g. `docs(storage): …`, `feat(scripts): …`.

---

## File Structure

| File | Responsibility |
|---|---|
| `scripts/zfs-replace-disk.sh` | Create. The entire guided tool: parsing, classification, prompts, guards, orchestration. Single self-contained file. |
| `scripts/tests/run-tests.sh` | Create. Bash assert harness; sources the script and unit-tests pure functions. |
| `scripts/tests/fixtures/*.txt` | Create. Captured `zpool status` outputs covering each pool state. |
| `scripts/tests/fake-bin/{zpool,smartctl,blockdev,lsblk,blkid,zdb}` | Create. Fake executables driven by env vars, for integration-style tests. |
| `self-hosting/storage/zfs-proxmox-config.md` | Modify. Add `### Replacing a failed disk` + `#### If the boot SSD dies instead` after line 110; fix the `rpool` example on line 95. |

Script internals, in dependency order:

```
log/warn/die/say_cmd          — output helpers
confirm / confirm_word        — /dev/tty prompts
run_cmd                       — print, confirm, execute (or skip if DRY_RUN)
require_root
list_pools / pool_health
parse_vdev_leaves             — zpool status text -> name|state|read|write|cksum|note
smart_signals                 — by-id -> reallocated:pending:uncorrect:health
classify_leaf                 — state + error counts + smart -> dead|dying|healthy
disk_serial / disk_size / disk_has_data
validate_replacement          — size + emptiness guards
wait_resilver
main                          — arg parsing, pool/disk selection, path dispatch
```

---

### Task 1: Test harness, fixtures, and `zpool status` parsing

**Files:**
- Create: `scripts/zfs-replace-disk.sh`
- Create: `scripts/tests/run-tests.sh`
- Create: `scripts/tests/fixtures/healthy-mirror.txt`, `degraded-faulted.txt`, `degraded-unavail.txt`, `online-cksum.txt`, `resilvering.txt`, `raidz2-degraded.txt`

**Interfaces:**
- Consumes: nothing.
- Produces: `parse_vdev_leaves` reads `zpool status` text on stdin, writes one line per **leaf** vdev to stdout as `name|state|read|write|cksum|note`. Container rows (the pool row, `mirror-N`, `raidzN-N`, `replacing-N`, `spares`, `logs`, `cache`, `special`, `dedup`) are excluded. `note` is the trailing free text (e.g. `too many errors`, `(resilvering)`) or empty. Also produces the sourcing contract every later task relies on: the script defines functions at top level and calls `main "$@"` only when executed directly.

- [ ] **Step 1: Write the fixtures**

`scripts/tests/fixtures/healthy-mirror.txt` — note ZFS indents the config block with tabs:

```
  pool: tank
 state: ONLINE
  scan: scrub repaired 0B in 04:12:33 with 0 errors on Sun Jul 12 04:12:34 2026
config:

	NAME                        STATE     READ WRITE CKSUM
	tank                        ONLINE       0     0     0
	  mirror-0                  ONLINE       0     0     0
	    wwn-0x5000c500c2f8832c  ONLINE       0     0     0
	    wwn-0x5000c500c2f8832d  ONLINE       0     0     0

errors: No known data errors
```

`scripts/tests/fixtures/degraded-faulted.txt`:

```
  pool: tank
 state: DEGRADED
status: One or more devices are faulted in response to persistent errors.
	Sufficient replicas exist for the pool to continue functioning in a
	degraded state.
action: Replace the faulted device, or use 'zpool clear' to mark the device
	repaired.
  scan: scrub repaired 0B in 04:12:33 with 0 errors on Sun Jul 12 04:12:34 2026
config:

	NAME                        STATE     READ WRITE CKSUM
	tank                        DEGRADED     0     0     0
	  mirror-0                  DEGRADED     0     0     0
	    wwn-0x5000c500c2f8832c  ONLINE       0     0     0
	    wwn-0x5000c500c2f8832d  FAULTED      6    98     0  too many errors

errors: No known data errors
```

`scripts/tests/fixtures/degraded-unavail.txt` — the disk is physically gone, so ZFS shows its GUID instead of a name:

```
  pool: tank
 state: DEGRADED
status: One or more devices could not be used because the label is missing or
	invalid.
  scan: none requested
config:

	NAME                        STATE     READ WRITE CKSUM
	tank                        DEGRADED     0     0     0
	  mirror-0                  DEGRADED     0     0     0
	    wwn-0x5000c500c2f8832c  ONLINE       0     0     0
	    9823741982374198237     UNAVAIL      0     0     0  was /dev/disk/by-id/wwn-0x5000c500c2f8832d

errors: No known data errors
```

`scripts/tests/fixtures/online-cksum.txt` — dying, still readable:

```
  pool: tank
 state: ONLINE
status: One or more devices has experienced an unrecoverable error.
  scan: scrub repaired 512K in 04:31:02 with 0 errors on Sun Jul 26 04:31:03 2026
config:

	NAME                        STATE     READ WRITE CKSUM
	tank                        ONLINE       0     0     0
	  mirror-0                  ONLINE       0     0     0
	    wwn-0x5000c500c2f8832c  ONLINE       0     0     0
	    wwn-0x5000c500c2f8832d  ONLINE       0     0     4

errors: No known data errors
```

`scripts/tests/fixtures/resilvering.txt`:

```
  pool: tank
 state: DEGRADED
status: One or more devices is currently being resilvered.
  scan: resilver in progress since Thu Jul 30 11:02:03 2026
	1.31T / 2.72T scanned at 412M/s, 986G / 2.72T issued at 302M/s
	984G resilvered, 35.42% done, 01:41:12 to go
config:

	NAME                          STATE     READ WRITE CKSUM
	tank                          DEGRADED     0     0     0
	  mirror-0                    DEGRADED     0     0     0
	    wwn-0x5000c500c2f8832c    ONLINE       0     0     0
	    replacing-1               DEGRADED     0     0     0
	      wwn-0x5000c500c2f8832d  FAULTED      0     0     0  too many errors
	      wwn-0x5000c500c2f8839f  ONLINE       0     0     0  (resilvering)

errors: No known data errors
```

`scripts/tests/fixtures/raidz2-degraded.txt`:

```
  pool: tank
 state: DEGRADED
  scan: none requested
config:

	NAME                        STATE     READ WRITE CKSUM
	tank                        DEGRADED     0     0     0
	  raidz2-0                  DEGRADED     0     0     0
	    wwn-0x5000c500c2f88301  ONLINE       0     0     0
	    wwn-0x5000c500c2f88302  ONLINE       0     0     0
	    wwn-0x5000c500c2f88303  FAULTED      0     0     0  too many errors
	    wwn-0x5000c500c2f88304  ONLINE       0     0     0

errors: No known data errors
```

- [ ] **Step 2: Write the failing test harness**

`scripts/tests/run-tests.sh`:

```bash
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

assert_eq 4 \
  "$(parse_vdev_leaves tank < "$FIX/resilvering.txt" | wc -l | tr -d ' ')" \
  'resilvering: replacing-1 container excluded, both children kept'

assert_eq 4 \
  "$(parse_vdev_leaves tank < "$FIX/raidz2-degraded.txt" | wc -l | tr -d ' ')" \
  'raidz2: 4 leaves, raidz2-0 container excluded'

assert_eq '' \
  "$(parse_vdev_leaves tank < "$FIX/degraded-faulted.txt" | grep -E '^(tank|mirror-0)\|' || true)" \
  'pool row and mirror row are never emitted as leaves'

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
```

- [ ] **Step 3: Run it to make sure it fails**

Run: `bash scripts/tests/run-tests.sh`
Expected: FAIL — `scripts/tests/run-tests.sh: line …: /home/…/scripts/../zfs-replace-disk.sh: No such file or directory`

- [ ] **Step 4: Create the script skeleton with `parse_vdev_leaves`**

`scripts/zfs-replace-disk.sh`. Note `set -euo pipefail` lives **inside `main`**, not at top level, so sourcing the file for tests does not change the harness's shell options:

```bash
#!/usr/bin/env bash
# zfs-replace-disk.sh — guided replacement of a failed or failing disk in a ZFS pool.
#
#   bash <(curl -sL https://raw.githubusercontent.com/kipavy/Wiki/main/scripts/zfs-replace-disk.sh)
#
# Scope: whole-disk data pools (no ZFS-on-root, no partition/boot handling).
# Docs:  self-hosting/storage/zfs-proxmox-config.md#replacing-a-failed-disk
#
# Never runs: zpool detach/remove/destroy, wipefs, dd, sgdisk.

# External commands, overridable for testing.
ZPOOL=${ZPOOL:-zpool}
SMARTCTL=${SMARTCTL:-smartctl}
BLOCKDEV=${BLOCKDEV:-blockdev}
LSBLK=${LSBLK:-lsblk}
BLKID=${BLKID:-blkid}
ZDB=${ZDB:-zdb}

DRY_RUN=${DRY_RUN:-0}
FORCE=${FORCE:-0}

# --- output helpers -------------------------------------------------------

log()  { printf '%s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# --- zpool status parsing -------------------------------------------------

# parse_vdev_leaves <pool> < zpool-status-text
# Emits one line per leaf vdev: name|state|read|write|cksum|note
parse_vdev_leaves() {
  local pool=$1
  awk -v pool="$pool" '
    /^config:/       { inconf = 1; next }
    /^errors:/       { inconf = 0 }
    inconf != 1      { next }
    $1 == "NAME" && $2 == "STATE" { seen_header = 1; next }
    seen_header != 1 { next }
    {
      line = $0
      gsub(/\t/, "  ", line)
      if (line ~ /^[[:space:]]*$/) next
      n = split(line, f, /[[:space:]]+/)
      i = (f[1] == "" ? 2 : 1)
      name = f[i]; state = f[i+1]; r = f[i+2]; w = f[i+3]; c = f[i+4]
      if (name == pool) next
      if (name ~ /^(mirror|raidz1|raidz2|raidz3|draid[0-9]*|replacing|spare|logs|cache|special|dedup)(-[0-9]+)?$/) next
      note = ""
      for (j = i + 5; j <= n; j++) note = (note == "" ? f[j] : note " " f[j])
      printf "%s|%s|%s|%s|%s|%s\n", name, state, r, w, c, note
    }
  '
}

main() {
  set -euo pipefail
  die "not implemented yet"
}

# Only run when executed, never when sourced by the test harness.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
```

- [ ] **Step 5: Run the tests and make sure they pass**

Run: `bash scripts/tests/run-tests.sh`
Expected: `6 passed, 0 failed`, exit 0.

- [ ] **Step 6: Commit**

```bash
git add scripts/zfs-replace-disk.sh scripts/tests/
git commit -m "feat(scripts): parse zpool status vdev leaves, with fixture tests"
```

---

### Task 2: Dead-vs-dying classification

**Files:**
- Modify: `scripts/zfs-replace-disk.sh` (add `smart_signals`, `classify_leaf`)
- Create: `scripts/tests/fake-bin/smartctl`
- Modify: `scripts/tests/run-tests.sh` (append a `classify_leaf` block)

**Interfaces:**
- Consumes: `parse_vdev_leaves` output lines from Task 1.
- Produces:
  - `smart_signals <by-id-path>` → prints `reallocated:pending:uncorrect:health` where the counts are integers and `health` is `PASSED`, `FAILED`, or `UNKNOWN`. Prints `0:0:0:UNKNOWN` and returns 0 when `smartctl` is missing or the device is unreadable — never fails the run.
  - `classify_leaf <state> <read> <write> <cksum> <smart_signals>` → prints exactly one of `dead`, `dying`, `healthy`.

- [ ] **Step 1: Write the failing tests**

Append to `scripts/tests/run-tests.sh`, before the summary `printf`:

```bash
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
```

- [ ] **Step 2: Write the fake `smartctl`**

`scripts/tests/fake-bin/smartctl` (remember `chmod +x`):

```bash
#!/usr/bin/env bash
# Fake smartctl for tests. Behaviour selected by $FAKE_SMART_MODE.
case "${FAKE_SMART_MODE:-healthy}" in
  healthy)
    echo "SMART overall-health self-assessment test result: PASSED"
    echo "  5 Reallocated_Sector_Ct   0x0033   100   100   010    Pre-fail  Always       -       0"
    echo "187 Reported_Uncorrect      0x0032   100   100   000    Old_age   Always       -       0"
    echo "197 Current_Pending_Sector  0x0012   100   100   000    Old_age   Always       -       0"
    echo "198 Offline_Uncorrectable   0x0010   100   100   000    Old_age   Offline      -       0"
    ;;
  dying)
    echo "SMART overall-health self-assessment test result: PASSED"
    echo "  5 Reallocated_Sector_Ct   0x0033   089   089   010    Pre-fail  Always       -       118"
    echo "187 Reported_Uncorrect      0x0032   100   100   000    Old_age   Always       -       2"
    echo "197 Current_Pending_Sector  0x0012   099   099   000    Old_age   Always       -       3"
    echo "198 Offline_Uncorrectable   0x0010   100   100   000    Old_age   Offline      -       0"
    ;;
  failing)
    echo "SMART overall-health self-assessment test result: FAILED!"
    echo "  5 Reallocated_Sector_Ct   0x0033   100   100   010    Pre-fail  Always       -       0"
    ;;
esac
exit 0
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `bash scripts/tests/run-tests.sh`
Expected: FAIL — `classify_leaf: command not found` / `smart_signals: command not found`.

- [ ] **Step 4: Implement both functions**

Insert into `scripts/zfs-replace-disk.sh` after `parse_vdev_leaves`:

```bash
# smart_signals <device> -> reallocated:pending:uncorrect:health
# Never fails: a missing smartctl or unreadable disk yields 0:0:0:UNKNOWN.
smart_signals() {
  local dev=$1 out realloc=0 pending=0 uncorr=0 health=UNKNOWN
  if ! out=$("$SMARTCTL" -H -A "$dev" 2>/dev/null); then
    if [[ -z ${out:-} ]]; then
      printf '0:0:0:UNKNOWN\n'
      return 0
    fi
  fi
  case $out in
    *"self-assessment test result: PASSED"*) health=PASSED ;;
    *"self-assessment test result: FAILED"*) health=FAILED ;;
  esac
  realloc=$(awk '$1 == 5   { print $NF + 0; exit }' <<<"$out")
  uncorr=$(awk  '$1 == 187 { print $NF + 0; exit }' <<<"$out")
  pending=$(awk '$1 == 197 { print $NF + 0; exit }' <<<"$out")
  printf '%s:%s:%s:%s\n' "${realloc:-0}" "${pending:-0}" "${uncorr:-0}" "$health"
}

# classify_leaf <state> <read> <write> <cksum> <smart_signals> -> dead|dying|healthy
classify_leaf() {
  local state=$1 r=$2 w=$3 c=$4 smart=$5
  case $state in
    FAULTED | UNAVAIL | REMOVED | OFFLINE)
      printf 'dead\n'; return 0 ;;
  esac
  local realloc pending uncorr health
  IFS=: read -r realloc pending uncorr health <<<"$smart"
  if [[ $state == DEGRADED ]] \
    || (( r > 0 || w > 0 || c > 0 )) \
    || (( ${realloc:-0} > 0 || ${pending:-0} > 0 || ${uncorr:-0} > 0 )) \
    || [[ ${health:-UNKNOWN} == FAILED ]]; then
    printf 'dying\n'; return 0
  fi
  printf 'healthy\n'
}
```

- [ ] **Step 5: Run the tests and make sure they pass**

Run: `chmod +x scripts/tests/fake-bin/smartctl && bash scripts/tests/run-tests.sh`
Expected: `21 passed, 0 failed`.

- [ ] **Step 6: Commit**

```bash
git add scripts/zfs-replace-disk.sh scripts/tests/
git commit -m "feat(scripts): classify failed disks as dead or dying from vdev state and SMART"
```

---

### Task 3: `/dev/tty` prompts, `run_cmd`, and the refusal guards

**Files:**
- Modify: `scripts/zfs-replace-disk.sh`
- Modify: `scripts/tests/run-tests.sh`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces:
  - `confirm <prompt>` → returns 0 only if the operator typed `y` or `Y`; bare Enter, anything else, or EOF returns 1.
  - `confirm_word <word> <prompt>` → returns 0 only on an exact match of `<word>`.
  - `run_cmd <cmd> [args…]` → prints `> cmd args`, asks `confirm`, then executes. With `DRY_RUN=1` it prints and returns 0 without executing or prompting. Returns 1 if the operator declines.
  - `require_root` → dies unless `EUID` is 0 or `DRY_RUN=1`.
  - `check_pool_actionable <pool> <health>` → dies unless health is `DEGRADED`/`FAULTED` or `FORCE=1`.

- [ ] **Step 1: Write the failing tests**

Append to `scripts/tests/run-tests.sh` before the summary. Note prompts read `/dev/tty`, so the tests feed a **pseudo-tty via `script`** rather than a pipe — that is the behaviour being asserted:

```bash
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
# Piping the script's own text to stdin must NOT auto-answer the prompt.
assert_eq 'RC=1' \
  "$(printf 'y\ny\ny\n' | script -qec "source '$SCRIPT'; confirm 'proceed?' && echo RC=0 || echo RC=1" /dev/null </dev/null 2>/dev/null | tr -d '\r' | grep -o 'RC=[01]' | tail -1)" \
  'stdin full of y cannot answer a /dev/tty prompt'

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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bash scripts/tests/run-tests.sh`
Expected: FAIL — `confirm: command not found`, and the `run_cmd`/`check_pool_actionable` assertions report empty actuals.

- [ ] **Step 3: Implement the prompts and guards**

Insert after the output helpers in `scripts/zfs-replace-disk.sh`. `die` uses `exit`, which would kill the sourcing test shell, so `check_pool_actionable` returns non-zero and lets `main` do the exiting:

```bash
# --- prompts ---------------------------------------------------------------
# All prompts read /dev/tty, never stdin: under `curl … | bash` the pipe IS
# stdin, so a plain `read` would consume the script's own source text and
# silently answer its own prompts. On a script that runs `zpool replace`,
# that is a data-loss bug.

confirm() { # confirm <prompt>  -> 0 only on y/Y; default is No
  local prompt=$1 reply=
  if [[ ! -r /dev/tty ]]; then
    warn "no tty available; refusing to assume consent for: $prompt"
    return 1
  fi
  printf '%s [y/N] ' "$prompt" > /dev/tty
  IFS= read -r reply < /dev/tty || return 1
  [[ $reply == y || $reply == Y ]]
}

confirm_word() { # confirm_word <word> <prompt>  -> 0 only on exact match
  local word=$1 prompt=$2 reply=
  if [[ ! -r /dev/tty ]]; then
    warn "no tty available; refusing to assume consent for: $prompt"
    return 1
  fi
  printf '%s (type %s to confirm) ' "$prompt" "$word" > /dev/tty
  IFS= read -r reply < /dev/tty || return 1
  [[ $reply == "$word" ]]
}

run_cmd() { # run_cmd <cmd> [args…] — print, confirm, execute
  printf '> %s\n' "$*"
  if [[ $DRY_RUN == 1 ]]; then
    return 0
  fi
  confirm "  run it?" || { log "  skipped."; return 1; }
  "$@"
}

# --- guards ----------------------------------------------------------------

require_root() {
  if [[ $DRY_RUN == 1 ]]; then return 0; fi
  [[ ${EUID:-$(id -u)} -eq 0 ]] || die "must run as root (ZFS commands need it). Try: sudo $0"
}

check_pool_actionable() { # <pool> <health>
  local pool=$1 health=$2
  case $health in
    DEGRADED | FAULTED) return 0 ;;
  esac
  if [[ $FORCE == 1 ]]; then
    warn "pool '$pool' is $health, continuing because --force was given."
    return 0
  fi
  warn "pool '$pool' is $health — nothing appears to need replacing."
  warn "Re-run with --force if you intend to replace a disk anyway."
  return 1
}
```

- [ ] **Step 4: Run the tests and make sure they pass**

Run: `bash scripts/tests/run-tests.sh`
Expected: `35 passed, 0 failed`. If `script` is unavailable, install `bsdutils`/`util-linux` — the pty tests are the point of this task and must not be skipped.

- [ ] **Step 5: Commit**

```bash
git add scripts/zfs-replace-disk.sh scripts/tests/run-tests.sh
git commit -m "feat(scripts): tty-safe prompts, dry-run runner, and pool/root guards"
```

---

### Task 4: Disk facts and replacement validation

**Files:**
- Modify: `scripts/zfs-replace-disk.sh`
- Create: `scripts/tests/fake-bin/blockdev`, `scripts/tests/fake-bin/lsblk`, `scripts/tests/fake-bin/blkid`, `scripts/tests/fake-bin/zdb`
- Modify: `scripts/tests/run-tests.sh`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces:
  - `disk_serial <device>` → serial string, or `unknown`.
  - `disk_size <device>` → size in bytes as an integer, or `0` if unreadable.
  - `disk_has_data <device>` → returns 0 (true) if the device carries a partition table, filesystem, or ZFS label; 1 if it looks blank.
  - `validate_replacement <new_dev> <reference_bytes>` → returns 0 if `new_dev` is at least `reference_bytes` and either blank or `WIPE`-confirmed; returns 1 otherwise.
  - `human_size <bytes>` → e.g. `2.7T`, for prompts.

- [ ] **Step 1: Write the failing tests**

Append to `scripts/tests/run-tests.sh`:

```bash
echo
echo "disk facts"
export PATH="$HERE/fake-bin:$PATH"
FB="$HERE/fake-bin"
assert_eq 'ZAD1234' \
  "$(SMARTCTL="$FB/smartctl" FAKE_SMART_MODE=healthy FAKE_SERIAL=ZAD1234 disk_serial /dev/disk/by-id/fake)" \
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
# A disk with data needs the literal word WIPE, not a y/N.
assert_eq 'RC=1' "$(tty_answer y "FAKE_DISK_STATE=partitioned FAKE_SIZE=3000592982016 \
  BLOCKDEV='$FB/blockdev' BLKID='$FB/blkid' LSBLK='$FB/lsblk' ZDB='$FB/zdb' \
  validate_replacement /dev/disk/by-id/fake 3000592982016")" \
  'disk with data: y is not enough'
assert_eq 'RC=0' "$(tty_answer WIPE "FAKE_DISK_STATE=partitioned FAKE_SIZE=3000592982016 \
  BLOCKDEV='$FB/blockdev' BLKID='$FB/blkid' LSBLK='$FB/lsblk' ZDB='$FB/zdb' \
  validate_replacement /dev/disk/by-id/fake 3000592982016")" \
  'disk with data: WIPE proceeds'
```

- [ ] **Step 2: Write the fakes**

`scripts/tests/fake-bin/blockdev`:

```bash
#!/usr/bin/env bash
# Fake blockdev. --getsize64 prints $FAKE_SIZE.
[[ ${1:-} == --getsize64 ]] && { echo "${FAKE_SIZE:-0}"; exit 0; }
exit 1
```

`scripts/tests/fake-bin/lsblk`:

```bash
#!/usr/bin/env bash
# Fake lsblk. Prints child partition names when $FAKE_DISK_STATE=partitioned.
case "${FAKE_DISK_STATE:-blank}" in
  partitioned) echo "fake"; echo "fake-part1"; echo "fake-part2" ;;
  *)           echo "fake" ;;
esac
exit 0
```

`scripts/tests/fake-bin/blkid`:

```bash
#!/usr/bin/env bash
# Fake blkid. Exits 0 with output only when the disk carries a signature.
case "${FAKE_DISK_STATE:-blank}" in
  partitioned) echo 'PTTYPE="gpt"'; exit 0 ;;
  filesystem)  echo 'TYPE="ext4"';  exit 0 ;;
esac
exit 2
```

`scripts/tests/fake-bin/zdb`:

```bash
#!/usr/bin/env bash
# Fake zdb -l. Reports a ZFS label only when $FAKE_DISK_STATE=zfs_label.
if [[ ${FAKE_DISK_STATE:-blank} == zfs_label ]]; then
  echo "------------------------------------"
  echo "LABEL 0"
  echo "------------------------------------"
  echo "    version: 5000"
  echo "    name: 'oldtank'"
  exit 0
fi
echo "failed to unpack label 0"
exit 1
```

Also extend `scripts/tests/fake-bin/smartctl` to answer `-i` for `disk_serial`, by adding this before the existing `case`:

```bash
if [[ ${1:-} == -i ]]; then
  echo "Device Model:     FAKE HDD 3000GB"
  echo "Serial Number:    ${FAKE_SERIAL:-UNKNOWNSERIAL}"
  exit 0
fi
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `chmod +x scripts/tests/fake-bin/* && bash scripts/tests/run-tests.sh`
Expected: FAIL — `disk_serial: command not found`, `human_size: command not found`, etc.

- [ ] **Step 4: Implement the disk-facts functions**

Insert after `smart_signals` in `scripts/zfs-replace-disk.sh`:

```bash
# --- disk facts ------------------------------------------------------------

disk_serial() { # <device> -> serial or "unknown"
  local dev=$1 out
  out=$("$SMARTCTL" -i "$dev" 2>/dev/null) || { printf 'unknown\n'; return 0; }
  local serial
  serial=$(awk -F: '/Serial [Nn]umber/ { gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit }' <<<"$out")
  printf '%s\n' "${serial:-unknown}"
}

disk_size() { # <device> -> bytes, or 0
  local dev=$1 bytes
  bytes=$("$BLOCKDEV" --getsize64 "$dev" 2>/dev/null) || { printf '0\n'; return 0; }
  printf '%s\n' "${bytes:-0}"
}

human_size() { # <bytes> -> e.g. 2.7T
  awk -v b="$1" 'BEGIN {
    split("B K M G T P", u, " ")
    i = 1
    while (b >= 1024 && i < 6) { b /= 1024; i++ }
    if (i <= 2) printf "%d%s\n", b, u[i]
    else if (b == int(b)) printf "%d%s\n", b, u[i]
    else printf "%.1f%s\n", b, u[i]
  }'
}

# disk_has_data <device> -> 0 if it carries a partition table, filesystem,
# or a ZFS label; 1 if it looks blank.
disk_has_data() {
  local dev=$1
  if "$BLKID" "$dev" >/dev/null 2>&1; then
    return 0
  fi
  if [[ $("$LSBLK" -ln -o NAME "$dev" 2>/dev/null | wc -l) -gt 1 ]]; then
    return 0
  fi
  if "$ZDB" -l "$dev" 2>/dev/null | grep -q "^ *name:"; then
    return 0
  fi
  return 1
}

# validate_replacement <new_dev> <reference_bytes> -> 0 if safe to use
validate_replacement() {
  local new=$1 ref=$2
  local new_bytes
  new_bytes=$(disk_size "$new")
  if (( new_bytes == 0 )); then
    warn "cannot read the size of $new — is it connected?"
    return 1
  fi
  if (( new_bytes < ref )); then
    warn "$new is $(human_size "$new_bytes"), smaller than the $(human_size "$ref") it must replace."
    warn "ZFS will refuse this. Use a disk of equal or greater size."
    return 1
  fi
  if disk_has_data "$new"; then
    warn "$new is not blank — it has a partition table, filesystem, or an old ZFS label."
    warn "Replacing into it destroys whatever is on it."
    confirm_word WIPE "  Overwrite $new ($(human_size "$new_bytes"))?" || {
      log "  aborted."
      return 1
    }
  fi
  return 0
}
```

- [ ] **Step 5: Run the tests and make sure they pass**

Run: `bash scripts/tests/run-tests.sh`
Expected: `48 passed, 0 failed`.

- [ ] **Step 6: Commit**

```bash
git add scripts/zfs-replace-disk.sh scripts/tests/
git commit -m "feat(scripts): read disk serial/size and refuse unsafe replacement disks"
```

---

### Task 5: Resilver monitoring and `main` orchestration

**Files:**
- Modify: `scripts/zfs-replace-disk.sh`
- Create: `scripts/tests/fake-bin/zpool`
- Modify: `scripts/tests/run-tests.sh`

**Interfaces:**
- Consumes: `parse_vdev_leaves`, `classify_leaf`, `smart_signals`, `confirm`, `run_cmd`, `require_root`, `check_pool_actionable`, `disk_serial`, `disk_size`, `human_size`, `validate_replacement`.
- Produces:
  - `resilver_active <pool>` → 0 if `zpool status` reports a resilver in progress.
  - `resilver_progress <pool>` → the human progress line, or empty.
  - `replace_dead <pool> <old_id> <new_id>` and `replace_dying <pool> <old_id> <new_id>` → emit the correct command sequence through `run_cmd`.
  - `main` → arg parsing (`--dry-run`, `--force`, `--pool <name>`, `-h|--help`), pool selection, disk selection, path dispatch, resilver wait, aftermath advice.

- [ ] **Step 1: Write the failing tests**

Append to `scripts/tests/run-tests.sh`:

```bash
echo
echo "resilver detection"
FB="$HERE/fake-bin"
assert_eq 'RC=0' "$(ZPOOL="$FB/zpool" FAKE_FIXTURE="$FIX/resilvering.txt" \
  resilver_active tank && echo RC=0 || echo RC=1)" \
  'resilver in progress is detected'
assert_eq 'RC=1' "$(ZPOOL="$FB/zpool" FAKE_FIXTURE="$FIX/healthy-mirror.txt" \
  resilver_active tank && echo RC=0 || echo RC=1)" \
  'healthy pool has no resilver'
assert_eq '984G resilvered, 35.42% done, 01:41:12 to go' \
  "$(ZPOOL="$FB/zpool" FAKE_FIXTURE="$FIX/resilvering.txt" resilver_progress tank)" \
  'progress line is extracted'

echo
echo "command sequences (dry-run)"
assert_eq '> zpool offline tank OLD
> zpool replace tank OLD NEW' \
  "$(DRY_RUN=1 ZPOOL=zpool replace_dead tank OLD NEW | grep '^> ')" \
  'dead path: offline then replace'
assert_eq '> zpool replace tank OLD NEW' \
  "$(DRY_RUN=1 ZPOOL=zpool replace_dying tank OLD NEW | grep '^> ')" \
  'dying path: replace only, never offline'
assert_eq '' \
  "$(DRY_RUN=1 ZPOOL=zpool replace_dead tank OLD NEW; DRY_RUN=1 ZPOOL=zpool replace_dying tank OLD NEW \
     | grep -E 'detach|remove|destroy|wipefs|sgdisk|dd ' || true)" \
  'neither path ever emits a destructive command'

echo
echo "--help and arg parsing"
assert_eq 'RC=0' "$(bash "$SCRIPT" --help >/dev/null 2>&1 && echo RC=0 || echo RC=1)" \
  '--help exits 0'
assert_eq 'RC=1' "$(bash "$SCRIPT" --bogus-flag >/dev/null 2>&1 && echo RC=0 || echo RC=1)" \
  'unknown flag exits non-zero'
```

- [ ] **Step 2: Write the fake `zpool`**

`scripts/tests/fake-bin/zpool`:

```bash
#!/usr/bin/env bash
# Fake zpool. `status` prints $FAKE_FIXTURE; `list` answers from env.
case "${1:-}" in
  status)
    cat "${FAKE_FIXTURE:?FAKE_FIXTURE not set}"
    ;;
  list)
    case "$*" in
      *health*) echo "${FAKE_HEALTH:-DEGRADED}" ;;
      *)        echo "${FAKE_POOLS:-tank}" ;;
    esac
    ;;
  *) echo "fake zpool: $*" ;;
esac
exit 0
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `chmod +x scripts/tests/fake-bin/zpool && bash scripts/tests/run-tests.sh`
Expected: FAIL — `resilver_active: command not found`, and `--help` exits non-zero because `main` still calls `die "not implemented yet"`.

- [ ] **Step 4: Implement resilver handling, the two paths, and `main`**

Add to `scripts/zfs-replace-disk.sh`, replacing the placeholder `main`:

```bash
# --- pools -----------------------------------------------------------------

list_pools() { "$ZPOOL" list -H -o name 2>/dev/null; }

pool_health() { "$ZPOOL" list -H -o health "$1" 2>/dev/null; }

pool_status() { "$ZPOOL" status "$1" 2>/dev/null; }

# --- resilver --------------------------------------------------------------

resilver_active() { # <pool>
  pool_status "$1" | grep -q "resilver in progress"
}

resilver_progress() { # <pool> -> progress line or empty
  pool_status "$1" \
    | awk '/resilvered,/ { gsub(/^[ \t]+|[ \t]+$/, ""); print; exit }'
}

wait_resilver() { # <pool>
  log ""
  log "Resilver started. This runs in the kernel: Ctrl-C here stops the"
  log "watching, NOT the resilver. Safe to leave, safe to interrupt."
  log ""
  while resilver_active "$1"; do
    local p
    p=$(resilver_progress "$1")
    printf '\r  %s' "${p:-resilvering…}"
    sleep 30
  done
  printf '\r%*s\r' 60 ''
  log "Resilver finished."
}

# --- replacement paths -----------------------------------------------------

replace_dead() { # <pool> <old_id> <new_id>
  log ""
  log "DEAD path: the disk is already out of service, so we take it offline"
  log "first, swap the hardware, then replace it."
  log ""
  run_cmd "$ZPOOL" offline "$1" "$2" || log "  (already offline? continuing.)"
  log ""
  log "Now physically swap the disk. Its serial is your only safe identifier."
  confirm "Swapped and the new disk is visible?" || die "aborted before replace."
  run_cmd "$ZPOOL" replace "$1" "$2" "$3" || die "replace declined or failed."
}

replace_dying() { # <pool> <old_id> <new_id>
  log ""
  log "DYING path: the old disk still reads, so we leave it ONLINE and"
  log "hot-replace. The resilver can then read from both the old disk and its"
  log "peer. Offlining it first would drop you to zero redundancy for the"
  log "whole resilver window."
  log ""
  run_cmd "$ZPOOL" replace "$1" "$2" "$3" || die "replace declined or failed."
}

usage() {
  cat <<'EOF'
zfs-replace-disk.sh — guided replacement of a failed or failing disk in a ZFS pool.

Usage: zfs-replace-disk.sh [--dry-run] [--force] [--pool NAME]

  --dry-run     Print the command sequence; execute nothing.
  --force       Operate on a pool that is not DEGRADED/FAULTED.
  --pool NAME   Skip pool selection.
  -h, --help    This text.

Scope: whole-disk data pools. Not for ZFS-on-root (rpool) — that needs
partition-table and proxmox-boot-tool steps this script deliberately omits.

Never runs: zpool detach/remove/destroy, wipefs, dd, sgdisk.
EOF
}

main() {
  set -euo pipefail

  local pool=
  while [[ $# -gt 0 ]]; do
    case $1 in
      --dry-run) DRY_RUN=1 ;;
      --force)   FORCE=1 ;;
      --pool)    pool=${2:?--pool needs a name}; shift ;;
      -h | --help) usage; return 0 ;;
      *) usage >&2; die "unknown option: $1" ;;
    esac
    shift
  done

  require_root
  command -v "$ZPOOL" >/dev/null 2>&1 || die "zpool not found — is ZFS installed?"
  command -v "$SMARTCTL" >/dev/null 2>&1 \
    || warn "smartctl not found; dead/dying detection will use vdev state only. (apt install smartmontools)"

  # 1. pick the pool
  if [[ -z $pool ]]; then
    local pools
    mapfile -t pools < <(list_pools)
    (( ${#pools[@]} > 0 )) || die "no ZFS pools found."
    if (( ${#pools[@]} == 1 )); then
      pool=${pools[0]}
    else
      log "Pools:"
      local i
      for i in "${!pools[@]}"; do
        log "  [$i] ${pools[$i]} ($(pool_health "${pools[$i]}"))"
      done
      printf 'Which pool? [0-%d] ' $(( ${#pools[@]} - 1 )) > /dev/tty
      local choice; IFS= read -r choice < /dev/tty
      pool=${pools[${choice:-0}]:?invalid choice}
    fi
  fi

  local health; health=$(pool_health "$pool")
  log ""
  log "Pool: $pool ($health)"
  log ""
  pool_status "$pool"

  check_pool_actionable "$pool" "$health" || exit 1

  # 2. classify every leaf
  local -a suspects=()
  local line name state r w c note smart verdict
  while IFS='|' read -r name state r w c note; do
    [[ -n $name ]] || continue
    smart=$(smart_signals "/dev/disk/by-id/$name")
    verdict=$(classify_leaf "$state" "$r" "$w" "$c" "$smart")
    [[ $verdict == healthy ]] && continue
    suspects+=("$name|$state|$verdict|$smart|$note")
  done < <(pool_status "$pool" | parse_vdev_leaves "$pool")

  (( ${#suspects[@]} > 0 )) || die "no failed or failing disk found in '$pool'."

  # 3. confirm the target by serial
  log ""
  log "Suspect disks:"
  local idx
  for idx in "${!suspects[@]}"; do
    IFS='|' read -r name state verdict smart note <<<"${suspects[$idx]}"
    log "  [$idx] $name"
    log "        state: $state ($verdict)  ${note:+note: $note}"
    log "        serial: $(disk_serial "/dev/disk/by-id/$name")  SMART(realloc:pending:uncorr:health): $smart"
  done
  local pick=0
  if (( ${#suspects[@]} > 1 )); then
    printf 'Replace which? [0-%d] ' $(( ${#suspects[@]} - 1 )) > /dev/tty
    IFS= read -r pick < /dev/tty
  fi
  IFS='|' read -r name state verdict smart note <<<"${suspects[${pick:-0}]:?invalid choice}"

  local old_id=$name
  local old_serial; old_serial=$(disk_serial "/dev/disk/by-id/$old_id")
  log ""
  log "Target: $old_id  serial: $old_serial  verdict: $verdict"
  confirm "Is that the disk you mean to replace?" || die "aborted."

  # 4. size reference: the failing disk, or its healthy peer if it is gone
  local ref_bytes; ref_bytes=$(disk_size "/dev/disk/by-id/$old_id")
  if (( ref_bytes == 0 )); then
    log "Old disk is unreadable; sizing against a healthy pool member instead."
    local peer peer_state
    while IFS='|' read -r peer peer_state _ _ _ _; do
      if [[ $peer_state == ONLINE && $peer != "$old_id" ]]; then
        ref_bytes=$(disk_size "/dev/disk/by-id/$peer")
        (( ref_bytes > 0 )) && break
      fi
    done < <(pool_status "$pool" | parse_vdev_leaves "$pool")
  fi
  (( ref_bytes > 0 )) || die "cannot determine the required disk size."
  log "Replacement must be at least $(human_size "$ref_bytes")."

  # 5. identify the new disk
  log ""
  log "Available /dev/disk/by-id/ entries (whole disks):"
  ls -1 /dev/disk/by-id/ 2>/dev/null | grep -vE -- '-part[0-9]+$' | sed 's/^/  /'
  printf 'by-id name of the NEW disk: ' > /dev/tty
  local new_id; IFS= read -r new_id < /dev/tty
  [[ -n $new_id ]] || die "no new disk given."
  [[ -e /dev/disk/by-id/$new_id ]] || die "/dev/disk/by-id/$new_id does not exist."
  [[ $new_id != "$old_id" ]] || die "new disk is the same as the old one."

  log "New disk: $new_id  serial: $(disk_serial "/dev/disk/by-id/$new_id")  size: $(human_size "$(disk_size "/dev/disk/by-id/$new_id")")"
  validate_replacement "/dev/disk/by-id/$new_id" "$ref_bytes" || die "replacement disk rejected."

  # 6. do it
  case $verdict in
    dead)  replace_dead  "$pool" "$old_id" "/dev/disk/by-id/$new_id" ;;
    dying) replace_dying "$pool" "$old_id" "/dev/disk/by-id/$new_id" ;;
  esac

  if [[ $DRY_RUN == 1 ]]; then
    log ""
    log "Dry run: nothing was executed."
    return 0
  fi

  wait_resilver "$pool"

  log ""
  pool_status "$pool"
  log ""
  log "Next steps:"
  log "  zpool clear $pool          # drop stale error counters"
  log "  zpool scrub $pool          # verify everything, monthly is a good cadence"
  log "  # If the new disk is larger and all members are now replaced:"
  log "  zpool set autoexpand=on $pool && zpool online -e $pool /dev/disk/by-id/$new_id"
  log ""
  log "Then re-check Scrutiny so the replaced disk stops alerting."
}
```

- [ ] **Step 5: Run the tests and make sure they pass**

Run: `bash scripts/tests/run-tests.sh`
Expected: `55 passed, 0 failed`.

- [ ] **Step 6: Verify the whole script parses and passes shellcheck**

Run: `bash -n scripts/zfs-replace-disk.sh && shellcheck scripts/zfs-replace-disk.sh scripts/tests/run-tests.sh`
Expected: `bash -n` silent. Fix any shellcheck error or warning; if shellcheck is not installed, `apt install shellcheck`. Note `run-tests.sh` sources the script, so `# shellcheck source=../zfs-replace-disk.sh` must stay.

- [ ] **Step 7: End-to-end check on a throwaway file-vdev pool**

This exercises the real `zpool` without touching `tank`. Run as root:

```bash
cd /var/tmp
truncate -s 512M d1.img d2.img d3.img
zpool create testpool mirror /var/tmp/d1.img /var/tmp/d2.img
zpool status testpool                      # ONLINE
# script must refuse a healthy pool:
bash /path/to/scripts/zfs-replace-disk.sh --pool testpool   # expect the --force refusal
# now break a member and re-run for real:
zpool offline testpool /var/tmp/d2.img
bash /path/to/scripts/zfs-replace-disk.sh --pool testpool --dry-run
# cleanup
zpool destroy testpool && rm -f /var/tmp/d[123].img
```

Expected: the healthy pool is refused without `--force`; the offlined member is classified `dead`; `--dry-run` prints the offline/replace sequence and executes nothing. Record any divergence and fix before committing. (File vdevs are not in `/dev/disk/by-id/`, so the new-disk prompt will reject `/var/tmp/d3.img` — confirm the refusal message is clear rather than a crash, and note it as a known limitation of the by-id-only design.)

- [ ] **Step 8: Commit**

```bash
git add scripts/zfs-replace-disk.sh scripts/tests/
git commit -m "feat(scripts): add guided zfs-replace-disk.sh with dead/dying paths"
```

---

### Task 6: Wiki documentation

**Files:**
- Modify: `self-hosting/storage/zfs-proxmox-config.md` (fix line 95; append after line 110)

**Interfaces:**
- Consumes: the script path and invocation from Task 5.
- Produces: the anchor `#replacing-a-failed-disk`, referenced by the script's header comment.

- [ ] **Step 1: Fix the misleading `rpool` example**

In `self-hosting/storage/zfs-proxmox-config.md:95`, change:

```shellscript
zpool attach rpool /dev/disk/by-id/wwn-0x5000c500c2f8832c /dev/disk/by-id/wwn-0x5000c500c2f8832d
```

to use `tank`, matching the pool name used everywhere else on the page (`rpool` implies a ZFS-on-root install, which is not this setup and would send a reader toward boot-disk steps that do not apply):

```shellscript
zpool attach tank /dev/disk/by-id/wwn-0x5000c500c2f8832c /dev/disk/by-id/wwn-0x5000c500c2f8832d
```

- [ ] **Step 2: Append the new section**

Append to the end of `self-hosting/storage/zfs-proxmox-config.md`:

````markdown
### Replacing a failed disk

{% hint style="danger" %}
Always identify disks by `/dev/disk/by-id/...` and cross-check the **serial number**. `/dev/sdX` names are reassigned at boot — acting on a stale `sdb` is how people wipe the healthy disk.
{% endhint %}

Guided script (does the identification for you, asks before every command):

```shellscript
bash <(curl -sL https://raw.githubusercontent.com/kipavy/Wiki/main/scripts/zfs-replace-disk.sh)
```

Add `--dry-run` to see the commands without running them. The manual steps below are the same thing by hand.

#### 1. Identify the disk

```shellscript
zpool status -v tank
```

The failing device is the leaf with a bad `STATE` or non-zero `READ`/`WRITE`/`CKSUM`:

```
	NAME                        STATE     READ WRITE CKSUM
	tank                        DEGRADED     0     0     0
	  mirror-0                  DEGRADED     0     0     0
	    wwn-0x5000c500c2f8832c  ONLINE       0     0     0
	    wwn-0x5000c500c2f8832d  FAULTED      6    98     0  too many errors
```

Get its serial and physical identity, then write the serial down before you open the case:

```shellscript
smartctl -i /dev/disk/by-id/wwn-0x5000c500c2f8832d   # Serial Number + model
ls -l /dev/disk/by-id/                              # by-id -> sdX mapping
```

If the disk is already gone, `zpool status` shows a bare number (its GUID) instead of a name, with a `was /dev/disk/by-id/...` note. Use that GUID in place of the name in the commands below.

#### 2. Dead or dying?

This decides everything that follows.

<table><thead><tr><th width="180">Symptom</th><th>Path</th><th>Why</th></tr></thead><tbody><tr><td><code>FAULTED</code>, <code>UNAVAIL</code>, <code>REMOVED</code>, or absent</td><td><strong>Dead</strong> — offline, swap, replace</td><td>ZFS already stopped using it; nothing to preserve.</td></tr><tr><td><code>ONLINE</code>/<code>DEGRADED</code> with CKSUM or READ/WRITE errors, or SMART reallocated/pending sectors</td><td><strong>Dying</strong> — hot-replace, leave it online</td><td>It still returns data. Keeping it online lets the resilver read from it <em>and</em> its peer.</td></tr></tbody></table>

Check SMART for the dying case:

```shellscript
smartctl -H -A /dev/disk/by-id/wwn-0x5000c500c2f8832d | grep -E 'result|Reallocated|Pending|Uncorrect'
```

#### 3a. Dead path

```shellscript
zpool offline tank /dev/disk/by-id/wwn-0x5000c500c2f8832d
# power down if the bays are not hot-swap, then physically swap the disk
zpool replace tank /dev/disk/by-id/wwn-0x5000c500c2f8832d /dev/disk/by-id/wwn-0x5000c500c2f8839f
```

#### 3b. Dying path

Connect the new disk **alongside** the old one (needs a free SATA port) and replace without offlining anything:

```shellscript
zpool replace tank /dev/disk/by-id/wwn-0x5000c500c2f8832d /dev/disk/by-id/wwn-0x5000c500c2f8839f
```

{% hint style="warning" %}
Do **not** `zpool offline` a disk that still reads. On a 2-disk mirror that leaves you with a single copy of everything for the entire resilver — hours of zero redundancy, exactly when a second disk is most likely to complain.

No free port? Then you have no choice but the dead path. Accept the risk and don't skip the scrub afterwards.
{% endhint %}

#### 4. Watch the resilver

```shellscript
zpool status -v tank
```

```
  scan: resilver in progress since Thu Jul 30 11:02:03 2026
	984G resilvered, 35.42% done, 01:41:12 to go
```

The pool stays online and usable throughout. When the resilver finishes, ZFS **automatically detaches the old device** — you never need `zpool detach` here, and running it by hand is a good way to break something.

#### 5. Afterwards

```shellscript
zpool clear tank    # reset stale error counters
zpool scrub tank    # full verify; do this monthly anyway
```

If the replacement is bigger and every member of the vdev has now been replaced, claim the extra space:

```shellscript
zpool set autoexpand=on tank
zpool online -e tank /dev/disk/by-id/wwn-0x5000c500c2f8839f
```

Then clear the old disk out of Scrutiny so it stops alerting — see [HDD Monitoring Proxmox](hdd-monitoring-proxmox.md).

#### What the error counters mean

<table><thead><tr><th width="120">Column</th><th>Meaning</th><th>Usual cause</th></tr></thead><tbody><tr><td><code>CKSUM</code></td><td>Data read back did not match its checksum. ZFS repaired it from the mirror.</td><td>Silent corruption: failing media, bad cable, bad RAM.</td></tr><tr><td><code>READ</code>/<code>WRITE</code></td><td>The I/O itself failed.</td><td>Dying drive, or a loose/failing SATA cable — reseat before condemning the disk.</td></tr></tbody></table>

{% hint style="info" %}
`DEGRADED` means redundancy is reduced, **not** that data is lost. On a 2-disk mirror with one disk gone, all your data is intact on the survivor — but you have no second copy, so replace it promptly and don't start a big rebalance in the meantime.
{% endhint %}

#### If the boot SSD dies instead

That is not a ZFS problem — Proxmox here lives on a single ext4/LVM SSD, and no part of it belongs to `tank`. Recovery is: reinstall PVE, `zpool import -f tank` to re-adopt the pool untouched, then restore the guests. Already written up in [#restore-method](proxmox-backup.md#restore-method "mention").

{% hint style="info" %}
**Would two mirrored SSDs (ZFS root) be better?** For uptime, yes: a dead boot SSD becomes a `zpool replace` instead of a reinstall, and you get OS snapshots to roll back a bad upgrade. But it is not free — ZFS write amplification plus sync-heavy Proxmox writes (`pmxcfs`, `pvestatd`, logs) chew through consumer SSDs that lack power-loss protection, ARC costs RAM, `local-lvm` thin provisioning gives way to zvols, and adopting it means reinstalling Proxmox.

Since guest data already goes to PBS and mirrors to R2, mirroring the root buys **less downtime, not more safety**.
{% endhint %}
````

- [ ] **Step 3: Verify the cross-links and anchors resolve**

Run:

```bash
grep -n 'restore-method\|hdd-monitoring-proxmox\|replacing-a-failed-disk' self-hosting/storage/zfs-proxmox-config.md
grep -n '^## Restore method' self-hosting/storage/proxmox-backup.md
grep -c 'rpool' self-hosting/storage/zfs-proxmox-config.md
```

Expected: the link targets exist, `## Restore method` is present in `proxmox-backup.md` (so `#restore-method` resolves), and `rpool` now appears **only** inside the "If the boot SSD dies instead" hint — the `zpool attach` example no longer uses it.

- [ ] **Step 4: Confirm no SUMMARY.md change is needed**

Run: `grep -n 'zfs-proxmox-config' SUMMARY.md`
Expected: one hit at line 106. New `###` sub-sections do not get `SUMMARY.md` entries — GitBook picks them up as in-page anchors. Do not add one.

- [ ] **Step 5: Commit**

```bash
git add self-hosting/storage/zfs-proxmox-config.md
git commit -m "docs(storage): document replacing a failed ZFS disk (dead vs dying paths)"
```

---

## Deviations during implementation

Recorded because the plan above no longer matches the code in these places.

1. **Arrow-key selection replaced typed input.** The plan had `main` prompt for
   the replacement disk's by-id name as free text. That is the worst possible
   UX for this situation — a 22-character hex string, typed at a console with no
   copy-paste, from a list whose entries differ by one character. Replaced with
   `select_menu`, a dependency-free arrow-key menu (up/down or j/k, Enter, q),
   plus `select_menu_numbered` as a fallback when raw mode is unavailable. Pool
   and failing-disk selection use it too. No ID is typed by hand anywhere.
2. **Candidate disks are filtered by canonical device, not by name.** Not in the
   plan, and a genuine safety hole: `/dev/disk/by-id/` holds several aliases per
   drive, so excluding pool members by name would still offer the healthy peer
   under its other alias. `excluded_canons` resolves every alias through
   `readlink -f` and also excludes the disks holding `/` — the Proxmox boot SSD
   belongs to no pool and would otherwise look like a free spare.
3. **Dead path reordered to offline → swap → choose → replace.** The plan chose
   the replacement before the swap, which meant the new disk was not yet
   connected and "appeared just now" detection could never fire. `replace_dead`
   was therefore split into `offline_dead_disk` + `apply_replace`, with
   `press_enter` for the physical swap, and `replace_dying` became
   `explain_dying_path` + the same `apply_replace`.
4. **Suspect disks sort dead-first**, so the default menu highlight is the most
   urgent disk rather than whichever came first in the vdev listing.
5. **Aftermath runs `zpool clear` and `zpool scrub` behind `y/N`** instead of
   printing them for the operator to copy (chosen by the user mid-implementation).
6. **Test harness forces bash.** `script -qec CMD` runs CMD under `$SHELL`,
   which is zsh on this machine — the first pty tests were silently exercising
   the wrong shell (zsh tolerates `read -r` but not `read -rn1`, and indexes
   arrays from 1). All pty probes now write a snippet to a temp file and run it
   with an explicit `bash` via the shared `in_pty` helper.
7. **Two plan assertions were themselves wrong** and were corrected, not coded
   around: the resilvering fixture has 3 leaf vdevs, not 4; and the
   destructive-command source scan matched the script's own comments and help
   text until comments and the usage heredoc were stripped.
8. **Two mutation checks added**, because both scans could otherwise pass
   vacuously: a deliberately naive stdin-reading `confirm()` must fail the
   `curl | bash` test, and the destructive-command scan must still find the real
   `zpool replace` call.
9. **shellcheck lint skipped** at the user's direction (not installed here);
   `bash -n` runs instead. Task 5 step 7's end-to-end file-vdev run could not be
   done on this machine — it has no ZFS — and is handed off to the PVE host.

## Self-Review

**Spec coverage:**

| Spec requirement | Task |
|---|---|
| A1 identify disk, no `/dev/sdX` | 6 (step 2, §1 + danger hint) |
| A2 dead-vs-dying decision | 2 (`classify_leaf`), 6 (§2 table) |
| A3 dead path incl. GUID fallback | 5 (`replace_dead`), 6 (§1 + §3a) |
| A4 dying path + free-port precondition | 5 (`replace_dying`), 6 (§3b + warning) |
| A5 monitor resilver, auto-detach | 5 (`wait_resilver`), 6 (§4) |
| A6 clear / scrub monthly / autoexpand / Scrutiny link | 5 (aftermath), 6 (§5) |
| A7 error-type reference | 6 (counters table + DEGRADED hint) |
| B boot SSD + mirrored-root trade-off | 6 (final subsection) |
| C `/dev/tty` prompts | 3 (incl. the explicit `curl \| bash` test) |
| C `N` default, print before run | 3 (`confirm`, `run_cmd`) |
| C serial confirmation | 5 (`main` step 3) |
| C refuse healthy pool w/o `--force` | 3 (`check_pool_actionable`) |
| C never detach/remove | 5 (asserted by the destructive-command test) |
| C reject smaller disk, peer fallback | 4 (`validate_replacement`), 5 (`main` step 4) |
| C reject non-blank disk, `WIPE` word | 4 (`validate_replacement`) |
| C `--dry-run` | 3 (`run_cmd`), 5 (arg parsing) |
| C graceful without `smartctl` | 2 (`smart_signals`), 5 (warning) |
| C Ctrl-C safe during resilver | 5 (`wait_resilver` message) |
| C text parsing, not `-j` | 1 (`parse_vdev_leaves`) |
| C root check | 3 (`require_root`) |
| D fix `rpool` example | 6 (step 1) |
| Testing: fixtures incl. RAIDZ | 1 |
| Testing: dry-run correctness | 5 |
| Testing: tty behaviour under piping | 3 |
| Testing: guard rejections | 3, 4, 5 |
| Testing: file-vdev end-to-end | 5 (step 7) |

No gaps.

**Placeholder scan:** none — every step carries runnable code or an exact command with an expected result.

**Type consistency:** `smart_signals` emits `realloc:pending:uncorr:health` in that order; `classify_leaf` and `main` both unpack it in that order, and the fake `smartctl`'s `dying` mode produces `118:3:2:PASSED` consistent with attribute 5=118, 197=3, 187=2. `parse_vdev_leaves` emits six `|`-separated fields; the two `while IFS='|' read` loops in `main` read six. `suspects[]` entries are `name|state|verdict|smart|note` and are unpacked with those five names in both loops. Function names are identical between definitions, tests, and `main` call sites.

**Test-count arithmetic:** 6 (T1) + 15 (T2) → 21, + 14 (T3) → 35, + 13 (T4) → 48, + 7 (T5) → 55. The expected totals in each task's run step match.
