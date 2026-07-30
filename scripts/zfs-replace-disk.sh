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
