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
READLINK=${READLINK:-readlink}
FINDMNT=${FINDMNT:-findmnt}
BYID=${BYID:-/dev/disk/by-id}

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

# --- interactive select ----------------------------------------------------
# Arrow-key menu. Renders to /dev/tty and prints ONLY the chosen index to
# stdout, so callers can capture it with $(…). Returns 1 if the operator quits.
# Items must be single-line. Falls back to a numbered prompt when the terminal
# cannot be put into raw mode.

select_menu() { # select_menu <prompt> <item>…
  local prompt=$1; shift
  local -a items=("$@")
  local n=${#items[@]}
  (( n > 0 )) || return 1

  if [[ ! -r /dev/tty ]]; then
    warn "no tty available; cannot present a selection menu."
    return 1
  fi

  local saved
  if ! saved=$(stty -g < /dev/tty 2>/dev/null); then
    select_menu_numbered "$prompt" "${items[@]}"
    return $?
  fi

  local cur=0 key rest i
  # shellcheck disable=SC2064
  trap "stty '$saved' < /dev/tty 2>/dev/null; printf '\n' > /dev/tty" RETURN INT

  printf '%s\n  (up/down move  enter select  q cancel)\n\n' "$prompt" > /dev/tty
  stty -echo -icanon min 1 time 0 < /dev/tty 2>/dev/null

  while :; do
    for (( i = 0; i < n; i++ )); do
      if (( i == cur )); then
        printf '\033[7m> %s\033[0m\033[K\n' "${items[i]}" > /dev/tty
      else
        printf '  %s\033[K\n' "${items[i]}" > /dev/tty
      fi
    done

    IFS= read -rn1 key < /dev/tty || { return 1; }
    case $key in
      $'\033')
        IFS= read -rn2 -t 0.1 rest < /dev/tty || rest=
        case $rest in
          '[A') (( cur > 0 )) && cur=$(( cur - 1 )) ;;
          '[B') (( cur < n - 1 )) && cur=$(( cur + 1 )) ;;
        esac
        ;;
      k) (( cur > 0 )) && cur=$(( cur - 1 )) ;;
      j) (( cur < n - 1 )) && cur=$(( cur + 1 )) ;;
      q | Q) return 1 ;;
      '' | $'\n' | $'\r')
        printf '%s\n' "$cur"
        return 0
        ;;
    esac
    # rewind over the list for the next repaint
    printf '\033[%dA' "$n" > /dev/tty
  done
}

select_menu_numbered() { # fallback when raw mode is unavailable
  local prompt=$1; shift
  local -a items=("$@")
  local n=${#items[@]} i reply
  printf '%s\n' "$prompt" > /dev/tty
  for (( i = 0; i < n; i++ )); do
    printf '  [%d] %s\n' "$i" "${items[i]}" > /dev/tty
  done
  printf 'Choice [0-%d, q to cancel]: ' $(( n - 1 )) > /dev/tty
  IFS= read -r reply < /dev/tty || return 1
  [[ $reply == q || $reply == Q ]] && return 1
  [[ $reply =~ ^[0-9]+$ ]] || return 1
  (( reply >= 0 && reply < n )) || return 1
  printf '%s\n' "$reply"
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

# --- pools -----------------------------------------------------------------

list_pools()  { "$ZPOOL" list -H -o name 2>/dev/null; }
pool_health() { "$ZPOOL" list -H -o health "$1" 2>/dev/null; }
pool_status() { "$ZPOOL" status "$1" 2>/dev/null; }

# --- candidate disks -------------------------------------------------------

canon_of() { "$READLINK" -f "$1" 2>/dev/null; }

# whole_disk_of <device> -> the physical disk(s) backing it (itself if already one)
whole_disk_of() {
  "$LSBLK" -npso NAME,TYPE "$1" 2>/dev/null | awk '$2 == "disk" { print $1 }'
}

# root_disks -> canonical whole disks holding /. Never offer these as a target:
# on this setup Proxmox lives on its own SSD that belongs to no pool, so it
# would otherwise appear as a perfectly valid "spare" disk.
root_disks() {
  local src
  src=$("$FINDMNT" -no SOURCE / 2>/dev/null) || return 0
  [[ -n $src ]] || return 0
  src=${src%%\[*}
  whole_disk_of "$src"
}

# excluded_canons -> every physical disk that must not be offered as a
# replacement: current members of any imported pool (resolved through their
# by-id aliases, so wwn-* and ata-* names of the same drive both match) and
# the disks holding the root filesystem.
excluded_canons() {
  {
    local pool name canon
    while read -r pool; do
      [[ -n $pool ]] || continue
      while IFS='|' read -r name _; do
        [[ -n $name && -e $BYID/$name ]] || continue
        canon=$(canon_of "$BYID/$name")
        [[ -n $canon ]] || continue
        printf '%s\n' "$canon"
        whole_disk_of "$canon"
      done < <(pool_status "$pool" | parse_vdev_leaves "$pool")
    done < <(list_pools)
    root_disks
  } | sort -u
}

# list_candidates -> byid_name|canon|bytes|serial|blank|data
# One line per physical disk, preferring the descriptive alias (ata-/nvme-,
# which carries model and serial) over the bare wwn- alias.
list_candidates() {
  local excl; excl=$(excluded_canons)
  local -A pick=()
  local link name canon
  for link in "$BYID"/*; do
    [[ -e $link ]] || continue
    name=${link##*/}
    case $name in
      *-part[0-9]*) continue ;;
    esac
    canon=$(canon_of "$link")
    [[ -n $canon ]] || continue
    if [[ -n $excl ]] && grep -qxF -- "$canon" <<<"$excl"; then continue; fi
    if [[ -n ${pick[$canon]:-} ]]; then
      case ${pick[$canon]} in
        wwn-*) pick[$canon]=$name ;;
      esac
      continue
    fi
    pick[$canon]=$name
  done
  for canon in "${!pick[@]}"; do
    name=${pick[$canon]}
    local blank=blank
    disk_has_data "$BYID/$name" && blank=data
    printf '%s|%s|%s|%s|%s\n' \
      "$name" "$canon" "$(disk_size "$BYID/$name")" "$(disk_serial "$BYID/$name")" "$blank"
  done | sort -t'|' -k1,1
}

# --- resilver --------------------------------------------------------------

resilver_active() { pool_status "$1" | grep -q "resilver in progress"; }

resilver_progress() {
  pool_status "$1" | awk '/resilvered,/ { gsub(/^[ \t]+|[ \t]+$/, ""); print; exit }'
}

wait_resilver() {
  log ""
  log "Resilver started. This runs in the kernel: Ctrl-C here stops the"
  log "watching, NOT the resilver. Safe to leave, safe to interrupt."
  log ""
  while resilver_active "$1"; do
    local p; p=$(resilver_progress "$1")
    printf '\r  %s\033[K' "${p:-resilvering...}"
    sleep 30
  done
  printf '\r\033[K'
  log "Resilver finished."
}

# --- replacement paths -----------------------------------------------------

press_enter() { # press_enter <message>
  [[ -r /dev/tty ]] || return 0
  printf '%s' "$1" > /dev/tty
  IFS= read -r _ < /dev/tty || true
  printf '\n' > /dev/tty
}

# Dead path, first half: the disk is already out of service, so offline it and
# swap the hardware BEFORE choosing a replacement — that way the new disk is
# actually present and can be flagged as newly-appeared in the menu.
offline_dead_disk() { # <pool> <old_id>
  log ""
  log "DEAD path: the disk is already out of service, so we offline it, swap"
  log "the hardware, then replace it."
  log ""
  run_cmd "$ZPOOL" offline "$1" "$2" || log "  (already offline? continuing.)"
}

# Dying path has no offline step at all — that is the whole point.
explain_dying_path() {
  log ""
  log "DYING path: the old disk still reads, so it stays ONLINE and we"
  log "hot-replace. The resilver can then read from both the old disk and its"
  log "peer. Offlining it first would drop you to zero redundancy for the"
  log "whole resilver window."
  log ""
  log "The replacement must already be connected alongside the old disk."
}

apply_replace() { # <pool> <old_id> <new_dev>
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

Nothing is typed by hand: pools and disks are chosen from arrow-key menus, and
every command is shown and confirmed before it runs.

Scope: whole-disk data pools. Not for ZFS-on-root (rpool) — that needs
partition-table and proxmox-boot-tool steps this script deliberately omits.

Never runs: zpool detach/remove/destroy, wipefs, dd, sgdisk.
EOF
}

# choose_candidate <ref_bytes> <pre_swap_canons> -> prints chosen "name|canon|…"
choose_candidate() {
  local ref=$1 pre=$2
  local -a lines=() labels=()
  local line name canon bytes serial blank tag
  while IFS= read -r line; do
    [[ -n $line ]] || continue
    IFS='|' read -r name canon bytes serial blank <<<"$line"
    tag=""
    if [[ -n $pre ]] && ! grep -qxF -- "$canon" <<<"$pre"; then
      tag="  <- appeared just now"
    fi
    lines+=("$line")
    labels+=("$(printf '%-34s %6s  serial %-14s %-5s%s' \
      "$name" "$(human_size "$bytes")" "$serial" "$blank" "$tag")")
  done < <(list_candidates)

  (( ${#lines[@]} > 0 )) || return 1

  # Newly-appeared disks first — that is almost always the one just plugged in.
  local -a order=() rest=()
  local i
  for i in "${!labels[@]}"; do
    case ${labels[i]} in
      *"appeared just now"*) order+=("$i") ;;
      *) rest+=("$i") ;;
    esac
  done
  order+=("${rest[@]}")

  local -a slabels=() slines=()
  for i in "${order[@]}"; do
    slabels+=("${labels[i]}")
    slines+=("${lines[i]}")
  done

  local idx
  idx=$(select_menu "Which disk is the replacement?" "${slabels[@]}") || return 1
  printf '%s\n' "${slines[idx]}"
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
    local -a pools=()
    mapfile -t pools < <(list_pools)
    (( ${#pools[@]} > 0 )) || die "no ZFS pools found."
    if (( ${#pools[@]} == 1 )); then
      pool=${pools[0]}
    else
      local -a plabels=() p
      for p in "${pools[@]}"; do
        plabels+=("$(printf '%-20s %s' "$p" "$(pool_health "$p")")")
      done
      local pidx
      pidx=$(select_menu "Which pool?" "${plabels[@]}") || die "cancelled."
      pool=${pools[pidx]}
    fi
  fi

  local health; health=$(pool_health "$pool")
  log ""
  log "Pool: $pool ($health)"
  log ""
  pool_status "$pool"

  check_pool_actionable "$pool" "$health" || exit 1

  # 2. classify every leaf
  local -a suspects=() slabels=()
  local name state r w c note smart verdict
  while IFS='|' read -r name state r w c note; do
    [[ -n $name ]] || continue
    smart=$(smart_signals "$BYID/$name")
    verdict=$(classify_leaf "$state" "$r" "$w" "$c" "$smart")
    [[ $verdict == healthy ]] && continue
    suspects+=("$name|$state|$verdict|$smart|$note")
    slabels+=("$(printf '%-24s %-9s %-6s serial %-14s %s' \
      "$name" "$state" "$verdict" "$(disk_serial "$BYID/$name")" "$note")")
  done < <(pool_status "$pool" | parse_vdev_leaves "$pool")

  (( ${#suspects[@]} > 0 )) || die "no failed or failing disk found in '$pool'."

  # Dead disks first, so the default highlight is the most urgent one rather
  # than whichever happened to appear first in the vdev listing.
  local -a dorder=() dyorder=() i
  for i in "${!suspects[@]}"; do
    case ${suspects[i]} in
      *'|dead|'*) dorder+=("$i") ;;
      *) dyorder+=("$i") ;;
    esac
  done
  dorder+=("${dyorder[@]}")
  local -a ssorted=() lsorted=()
  for i in "${dorder[@]}"; do
    ssorted+=("${suspects[i]}")
    lsorted+=("${slabels[i]}")
  done
  suspects=("${ssorted[@]}")
  slabels=("${lsorted[@]}")

  # 3. confirm the target
  local pick=0
  if (( ${#suspects[@]} > 1 )); then
    pick=$(select_menu "Which disk is failing?" "${slabels[@]}") || die "cancelled."
  else
    log ""
    log "Failing disk: ${slabels[0]}"
  fi
  IFS='|' read -r name state verdict smart note <<<"${suspects[pick]}"

  local old_id=$name
  local old_serial; old_serial=$(disk_serial "$BYID/$old_id")
  log ""
  log "Target: $old_id"
  log "  serial: $old_serial   state: $state   verdict: $verdict"
  log "  SMART(realloc:pending:uncorr:health): $smart"
  confirm "Is that the disk you mean to replace?" || die "aborted."

  # 4. size reference: the failing disk, or a healthy peer if it is gone
  local ref_bytes; ref_bytes=$(disk_size "$BYID/$old_id")
  if (( ref_bytes == 0 )); then
    log "Old disk is unreadable; sizing against a healthy pool member instead."
    local peer peer_state
    while IFS='|' read -r peer peer_state _ _ _ _; do
      if [[ $peer_state == ONLINE && $peer != "$old_id" ]]; then
        ref_bytes=$(disk_size "$BYID/$peer")
        (( ref_bytes > 0 )) && break
      fi
    done < <(pool_status "$pool" | parse_vdev_leaves "$pool")
  fi
  (( ref_bytes > 0 )) || die "cannot determine the required disk size."
  log "Replacement must be at least $(human_size "$ref_bytes")."

  # 5. dead path: offline and physically swap BEFORE choosing the replacement,
  #    so the disk you just plugged in can be detected and offered first.
  local pre_canons=""
  if [[ $verdict == dead ]]; then
    offline_dead_disk "$pool" "$old_id"
    pre_canons=$(list_candidates | cut -d'|' -f2)
    log ""
    log "Now physically swap the disk. Serial $old_serial is the one to pull."
    log "Power down first if the bays are not hot-swap."
    press_enter "Press Enter once the new disk is connected... "
  else
    explain_dying_path
  fi

  local chosen new_name new_canon new_bytes new_serial new_blank
  chosen=$(choose_candidate "$ref_bytes" "$pre_canons") \
    || die "no replacement disk selected."
  IFS='|' read -r new_name new_canon new_bytes new_serial new_blank <<<"$chosen"

  log ""
  log "  new: $new_name  $(human_size "$new_bytes")  serial $new_serial  ($new_blank)"
  log "  old: $old_id  $(human_size "$ref_bytes")  serial $old_serial"
  confirm "Replace old with new?" || die "aborted."

  validate_replacement "$BYID/$new_name" "$ref_bytes" || die "replacement disk rejected."

  # 6. do it
  apply_replace "$pool" "$old_id" "$BYID/$new_name"

  if [[ $DRY_RUN == 1 ]]; then
    log ""
    log "Dry run: nothing was executed."
    return 0
  fi

  wait_resilver "$pool"

  log ""
  pool_status "$pool"

  log ""
  log "Clear the stale error counters?"
  run_cmd "$ZPOOL" clear "$pool" || true
  log ""
  log "Scrub now to verify the whole pool? (takes hours, pool stays usable)"
  run_cmd "$ZPOOL" scrub "$pool" || true

  if (( new_bytes > ref_bytes )); then
    log ""
    log "The new disk is larger. Once EVERY member of the vdev is this size:"
    log "  zpool set autoexpand=on $pool"
    log "  zpool online -e $pool $BYID/$new_name"
  fi

  log ""
  log "Done. Re-check Scrutiny so the replaced disk stops alerting."
}

# Only run when executed, never when sourced by the test harness.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
