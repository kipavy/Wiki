# ZFS disk replacement: wiki docs + guided script

**Date:** 2026-07-30
**Status:** approved, ready for implementation

## Problem

The wiki documents how to *add* disks to a ZFS pool (`zfs-proxmox-config.md:78-110`) and how to
*monitor* disk health (`hdd-monitoring-proxmox.md`, Scrutiny + alerting), but nothing about what to
do when a disk actually fails. A repo-wide grep finds zero occurrences of `zpool replace`,
`zpool offline`, `zpool clear`, `scrub`, `resilver`, or `DEGRADED`.

So the path from "Scrutiny just alerted me" to "pool is healthy again" is undocumented, and it is
exactly the path that will be walked under time pressure, months from now, having forgotten the
commands.

## Target environment

Decided with the user; the design is scoped to this and deliberately not generalised:

- Proxmox VE on a **single ext4/LVM SSD** (hence `local-lvm` storage)
- **2 HDDs in a ZFS mirror pool**, whole disks (not partitions), referenced by `/dev/disk/by-id/`
- `smartmontools` present (installed as part of the Scrutiny collector setup)

Consequence: the pool contains **no boot or root members**, so nothing in this work touches
partition tables, ESPs, or `proxmox-boot-tool`. A dead boot SSD is a separate, non-ZFS recovery
path that the wiki already covers.

## Deliverables

### A. `### Replacing a failed disk` — new section in `self-hosting/storage/zfs-proxmox-config.md`

Placed after the existing `### Add disk to an existing pool` section. Must stand alone: readable and
sufficient without the script, since the script may be unavailable or distrusted at the moment of
failure.

Sub-sections, in the order the work is actually done:

1. **Identify the disk.** Read `zpool status -v`; map vdev name → `/dev/disk/by-id/` → serial
   (`smartctl -i`) → physical bay. Explicit warning: never use `/dev/sdX`, it renumbers across
   reboots, and acting on a stale `sdX` name means operating on the healthy disk.
2. **Dead or dying?** The decision that drives everything downstream:
   - `FAULTED` / `UNAVAIL` / `REMOVED`, or device absent → **dead path**
   - `ONLINE` or `DEGRADED` with non-zero READ/WRITE/CKSUM, or SMART reallocated / pending sectors
     → **dying path**
3. **Dead path.** `zpool offline <pool> <old-id>` → physical swap → `zpool replace <pool> <old-id>
   <new-id>`. Note the fallback for a disk whose `by-id` link is already gone: identify it by GUID
   via `zpool status -g` and pass the GUID to `zpool replace`.
4. **Dying path.** `zpool replace` with **both disks attached and the old one still online**, so the
   resilver can read from the dying disk as well as its peer. State plainly why: offlining a
   readable disk first drops the mirror to zero redundancy for the whole resilver window. Note the
   precondition — a free SATA port; without one you must fall back to the dead path.
5. **Monitor the resilver.** `zpool status -v`, how to read the progress/ETA line, and that
   `zpool replace` auto-detaches the old device when the resilver completes (no manual
   `zpool detach` is needed, or wanted).
6. **Aftermath.** `zpool clear` for stale counters, `zpool scrub` plus a monthly cadence recommendation,
   `autoexpand=on` + `zpool online -e` if the replacement is larger, and re-checking Scrutiny —
   cross-linked to `hdd-monitoring-proxmox.md`.
7. **Error-type reference.** What CKSUM vs READ/WRITE errors indicate (silent corruption or cabling
   vs. failing media), and what `DEGRADED` does and does not mean for data integrity.

### B. `#### If the boot SSD dies instead` — short subsection

Two paragraphs, no command duplication:

- A dead boot SSD is not a ZFS problem. Recovery is reinstall PVE → `zpool import -f <pool>` →
  restore guests from PBS, which is already written up. Cross-link
  `proxmox-backup.md#restore-method`.
- The mirrored-ZFS-root trade-off, recorded so the decision can be made deliberately later rather
  than rediscovered: two mirrored SSDs as ZFS root survive a boot-disk death without a reinstall and
  add OS snapshots/rollback, but cost SSD endurance (sync-heavy Proxmox writes plus ZFS write
  amplification, and PLP-less consumer drives wear fast), cost RAM to ARC, give up `local-lvm` thin
  provisioning in favour of zvols, and require a reinstall to adopt. Given guest data already goes
  to PBS and is mirrored to R2, mirroring the root buys reduced downtime, not data safety.

### C. `scripts/zfs-replace-disk.sh` — interactive guided script

First script in a previously markdown-only repo. Documented invocation, raw GitHub URL, no
shortener (user's choice):

```shellscript
bash <(curl -sL https://raw.githubusercontent.com/kipavy/Wiki/main/scripts/zfs-replace-disk.sh)
```

**Flow:** enumerate pools → print `zpool status` → find unhealthy leaf vdevs → classify dead vs
dying → confirm the target disk by reading its **serial number** back to the operator → walk the
appropriate command sequence, each step behind a `y/N` prompt → follow the resilver to completion →
print final `zpool status`.

**Safety requirements** — these are the reason the script exists rather than a copy-paste block, and
each is testable:

- Every prompt reads from **`/dev/tty`**, not stdin. Under `curl … | bash` the pipe *is* stdin, so a
  naive `read -p` consumes the script's own source text and auto-answers its own prompts — on a
  script that runs `zpool replace`, that is a data-loss bug. Reading from `/dev/tty` makes the
  script correct under every invocation form.
- Each command is printed before it runs; **`N` is the default** on every prompt (bare Enter
  declines).
- Target confirmation is by serial number, not device path.
- Refuses to act on a pool that is not `DEGRADED`/`FAULTED` unless `--force` is passed.
- Never runs `zpool detach` or `zpool remove`. Replacement only.
- Rejects a replacement disk smaller than the one it replaces. When the old disk is gone, size is
  compared against its surviving mirror peer.
- Refuses a replacement disk that carries partitions, a filesystem, or an existing ZFS label
  (`blkid`, `lsblk`, `zdb -l`) unless the operator types the literal word `WIPE` (a `y/N` prompt is too easy to fat-finger here).
- `--dry-run` prints the full sequence without executing anything.
- Degrades gracefully when `smartctl` is absent: classification falls back to vdev state alone and
  says so, rather than failing.
- Ctrl-C during resilver monitoring exits the script without aborting the resilver (it continues in
  the kernel); the script says this before it starts waiting.

**Implementation notes:** parse `zpool status` text rather than depending on `zpool status -j`,
which is only available in newer OpenZFS than Proxmox reliably ships. Size checks via
`blockdev --getsize64`. SMART signals from `smartctl -H -A`: attributes 5 (Reallocated_Sector_Ct),
187 (Reported_Uncorrect), 197 (Current_Pending_Sector), 198 (Offline_Uncorrectable), plus overall
health. Requires root; check and exit with a clear message if not.

### D. Fix `zfs-proxmox-config.md:95`

The `zpool attach` example uses `rpool`, which implies a ZFS-on-root install the user does not have
and would send a reader down the boot-disk path this design deliberately excludes. Change to `tank`
to match the pool naming used elsewhere on the page.

## Testing

The script's parsing and classification logic is the part that can be wrong in a way that damages
data, and it cannot be exercised safely against the live pool.

- Unit-test parsing and dead/dying classification against **captured `zpool status` fixtures**:
  healthy mirror, `DEGRADED` with one `FAULTED` leaf, `DEGRADED` with a `UNAVAIL`/missing device,
  `ONLINE` with non-zero CKSUM, resilver in progress, and a RAIDZ layout for good measure.
- Verify `--dry-run` produces the correct sequence for each fixture and executes nothing.
- Verify the `/dev/tty` prompt behaviour explicitly under `curl … | bash`-style piping: prompts must
  still block and wait for the operator.
- Verify the guard conditions each reject as specified: healthy pool without `--force`, undersized
  replacement, replacement with existing data, missing `smartctl`, non-root.
- Optionally exercise the end-to-end happy path against a **scratch pool built on file vdevs**
  (`truncate` + `zpool create`), where faulting and replacing a "disk" is free and reversible.

## Out of scope

- ZFS-on-root / `rpool` replacement, and everything partition- and `proxmox-boot-tool`-related
- `zpool detach` / vdev removal / pool destruction
- RAIDZ expansion and capacity growth (already documented on the page)
- Actually mirroring the boot SSD; section B records the trade-off, it does not perform a migration
- Any Cloudflare short-URL redirect; the raw GitHub URL is the documented entry point
