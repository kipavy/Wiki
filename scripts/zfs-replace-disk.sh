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

# --- SMART and classification ---------------------------------------------

# smart_signals <device> -> reallocated:pending:uncorrect:health
# Never fails: a missing smartctl or unreadable disk yields 0:0:0:UNKNOWN.
smart_signals() {
  local dev=$1 out realloc=0 pending=0 uncorr=0 health=UNKNOWN
  if ! out=$("$SMARTCTL" -H -A "$dev" 2>/dev/null) && [[ -z ${out:-} ]]; then
    printf '0:0:0:UNKNOWN\n'
    return 0
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

# --- disk facts ------------------------------------------------------------

disk_serial() { # <device> -> serial or "unknown"
  local dev=$1 out serial
  out=$("$SMARTCTL" -i "$dev" 2>/dev/null) || { printf 'unknown\n'; return 0; }
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
  local new=$1 ref=$2 new_bytes
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

main() {
  set -euo pipefail
  die "not implemented yet"
}

# Only run when executed, never when sourced by the test harness.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
