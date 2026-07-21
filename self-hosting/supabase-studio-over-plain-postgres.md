# Supabase Studio over plain Postgres

A lightweight, self-hosted alternative to [Neon.tech](https://neon.tech)'s console: just the **Supabase Studio SQL editor + table editor**, pointed at an ordinary Postgres container. No auth, Realtime, Storage, Kong, PostgREST, or Logflare/analytics — three containers total.

Great when you want a nice web UI over a local Postgres (browsing tables, running SQL) without paying for, or being rate-limited by, a hosted provider.

<figure><img src="../.gitbook/assets/image (1).png" alt=""><figcaption></figcaption></figure>

```mermaid
flowchart LR
    classDef ui fill:#3ecf8e,stroke:#1a7f52,color:#062e1c,stroke-width:2px;
    classDef api fill:#f59e0b,stroke:#b45309,color:#fff,stroke-width:2px;
    classDef db fill:#1e293b,stroke:#94a3b8,color:#fff,stroke-width:2px;

    Browser(("🌐 localhost:8000")):::ui
    Studio["studio<br/>(dashboard UI)"]:::ui
    Meta["meta<br/>(postgres-meta API)"]:::api
    DB[("postgres<br/>your database")]:::db

    Browser --> Studio
    Studio -- "STUDIO_PG_META_URL<br/>http://meta:8080" --> Meta
    Meta -- "SQL :5432" --> DB
```

## Why this works without the rest of the stack

The whole Supabase self-hosting stack normally routes Studio → **Kong** → everything. But for the **SQL editor and table editor specifically**, Studio talks to `postgres-meta` **directly** via `STUDIO_PG_META_URL` — Kong never sat between those two. So dropping Kong (and auth/realtime/storage/rest) changes nothing for the two features we care about.

## `docker-compose.yml`

```yaml
name: supastudio-lite

services:
  # 1) Your actual database (stock Postgres — no Supabase fork needed).
  postgres:
    image: postgres:17-alpine
    container_name: supastudio-db
    restart: unless-stopped
    ports:
      - "${POSTGRES_PORT_EXTERNAL:-5433}:5432"
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "postgres", "-h", "localhost"]
      interval: 5s
      timeout: 5s
      retries: 10
    volumes:
      - db-data:/var/lib/postgresql/data

  # 2) The companion API Studio queries the DB through.
  meta:
    image: supabase/postgres-meta:v0.96.6
    container_name: supastudio-meta
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      PG_META_PORT: 8080
      PG_META_DB_HOST: postgres
      PG_META_DB_PORT: 5432
      PG_META_DB_NAME: ${POSTGRES_DB}
      PG_META_DB_USER: postgres
      PG_META_DB_PASSWORD: ${POSTGRES_PASSWORD}
      CRYPTO_KEY: ${PG_META_CRYPTO_KEY}

  # 3) The dashboard UI.
  studio:
    image: supabase/studio:2026.07.07-sha-a6a04f2
    container_name: supastudio-ui
    restart: unless-stopped
    depends_on:
      meta:
        condition: service_started
    ports:
      - "${STUDIO_PORT_EXTERNAL:-8000}:3000"
    environment:
      HOSTNAME: "0.0.0.0"

      # --- What actually matters for SQL editor + table editor ---
      STUDIO_PG_META_URL: http://meta:8080
      POSTGRES_HOST: postgres
      POSTGRES_PORT: 5432
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_USER_READ_WRITE: postgres
      PG_META_CRYPTO_KEY: ${PG_META_CRYPTO_KEY}
      DEFAULT_ORGANIZATION_NAME: ${STUDIO_DEFAULT_ORGANIZATION}
      DEFAULT_PROJECT_NAME: ${STUDIO_DEFAULT_PROJECT}

      # --- Kills the Logflare/analytics dependency (see Gotchas) ---
      ENABLED_FEATURES_LOGS_ALL: "false"

      # --- REST/Auth pages we don't run. Present only so Studio doesn't
      #     null-error on boot; SUPABASE_URL points at meta just to resolve. ---
      SUPABASE_URL: http://meta:8080
      SUPABASE_PUBLIC_URL: ${SUPABASE_PUBLIC_URL}
      SUPABASE_ANON_KEY: ${ANON_KEY}
      SUPABASE_SERVICE_KEY: ${SERVICE_ROLE_KEY}
      AUTH_JWT_SECRET: ${JWT_SECRET}
      PGRST_DB_SCHEMAS: ${PGRST_DB_SCHEMAS}

  # 4) Nightly backup sidecar — scheduled pg_dump with rotation/retention.
  #    Writes compressed dumps to ./backups. See "Automated backups" below.
  backup:
    image: prodrigestivill/postgres-backup-local:17-alpine
    container_name: supastudio-backup
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
    volumes:
      - ./backups:/backups
    environment:
      POSTGRES_HOST: postgres
      POSTGRES_PORT: 5432
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      SCHEDULE: ${BACKUP_SCHEDULE:-@daily}
      BACKUP_ON_START: "TRUE"
      BACKUP_KEEP_DAYS: ${BACKUP_KEEP_DAYS:-7}
      BACKUP_KEEP_WEEKS: ${BACKUP_KEEP_WEEKS:-4}
      BACKUP_KEEP_MONTHS: ${BACKUP_KEEP_MONTHS:-6}
      TZ: ${TZ:-UTC}

  # 5) Off-host mirror sidecar — rclone syncs ./backups -> Cloudflare R2 on a
  #    schedule, entirely inside compose. No host cron, no docker-socket scheduler.
  #    Creds come from .env as RCLONE_CONFIG_* so no host rclone.conf is needed.
  backup-mirror:
    image: rclone/rclone:1.69
    container_name: supastudio-backup-mirror
    restart: unless-stopped
    depends_on:
      - backup
    volumes:
      - ./backups:/data:ro
    environment:
      RCLONE_CONFIG_R2BACKUP_TYPE: s3
      RCLONE_CONFIG_R2BACKUP_PROVIDER: Cloudflare
      RCLONE_CONFIG_R2BACKUP_ACCESS_KEY_ID: ${R2_ACCESS_KEY_ID}
      RCLONE_CONFIG_R2BACKUP_SECRET_ACCESS_KEY: ${R2_SECRET_ACCESS_KEY}
      RCLONE_CONFIG_R2BACKUP_ENDPOINT: ${R2_ENDPOINT}
      RCLONE_CONFIG_R2BACKUP_ACL: private
      RCLONE_CONFIG_R2BACKUP_NO_CHECK_BUCKET: "true"
      R2_BUCKET: ${R2_BUCKET}
      MIRROR_INTERVAL: ${BACKUP_MIRROR_INTERVAL:-86400}
    entrypoint:
      - /bin/sh
      - -c
      - |
        while true; do
          echo "[mirror] $(date -u '+%Y-%m-%d %H:%M:%S')Z syncing /data -> r2backup:$${R2_BUCKET}/supastudio";
          rclone sync /data "r2backup:$${R2_BUCKET}/supastudio" --copy-links --stats-one-line \
            && echo "[mirror] ok" || echo "[mirror] FAILED (will retry next cycle)";
          sleep "$${MIRROR_INTERVAL}";
        done

volumes:
  db-data:
```

## `.env`

```bash
# ---- Postgres ----
POSTGRES_PASSWORD=postgres
POSTGRES_DB=postgres
POSTGRES_PORT_EXTERNAL=5433          # host port; container is always 5432

# ---- Studio UI ----
STUDIO_PORT_EXTERNAL=8000
STUDIO_DEFAULT_ORGANIZATION=Local
STUDIO_DEFAULT_PROJECT=dev
SUPABASE_PUBLIC_URL=http://localhost:8000

# ---- pg-meta encryption (any 32+ char string) ----
PG_META_CRYPTO_KEY=this-is-a-32-char-min-crypto-key-01

# ---- Demo keys: only touched by API/Auth pages we don't run.
#      Safe as-is for a local, non-exposed setup. From Supabase .env.example. ----
JWT_SECRET=your-super-secret-jwt-token-with-at-least-32-characters-long
ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE
SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJzZXJ2aWNlX3JvbGUiLAogICAgImlzcyI6ICJzdXBhYmFzZS1kZW1vIiwKICAgICJpYXQiOiAxNjQxNzY5MjAwLAogICAgImV4cCI6IDE3OTk1MzU2MDAKfQ.DaYlNEoUrrEn2Ig7tqibS-PHK5vgusbcbo7X36XVt4Q

# ---- Schemas Studio exposes ----
PGRST_DB_SCHEMAS=public,graphql_public

# ---- Backup sidecar ----
# SCHEDULE: @daily / @weekly / @monthly, or 6-field cron (with seconds).
BACKUP_SCHEDULE=@daily
BACKUP_KEEP_DAYS=7
BACKUP_KEEP_WEEKS=4
BACKUP_KEEP_MONTHS=6
TZ=Europe/Paris

# ---- Off-host mirror sidecar (rclone -> R2). Keep real creds out of git. ----
R2_BUCKET=db-backups
R2_ENDPOINT=https://<ACCOUNT_ID>.r2.cloudflarestorage.com
R2_ACCESS_KEY_ID=<ACCESS_KEY_ID>
R2_SECRET_ACCESS_KEY=<SECRET_ACCESS_KEY>
BACKUP_MIRROR_INTERVAL=86400
```

## Run

```bash
docker compose up -d
# open http://localhost:8000  ->  redirects to /project/default
```

Connect apps to the DB at `postgresql://postgres:postgres@localhost:5433/postgres`.

## Gotchas (each verified, not guessed)

* **Logflare / analytics health-check.** Older Studio tags hard-depended on the `analytics` (Logflare) service and never went `healthy` in a trimmed stack. Current tags gate it behind **`ENABLED_FEATURES_LOGS_ALL: "false"`** (set above), so the container's health-check (`GET /api/platform/profile`) returns `200` **without** any analytics service, stub, or disabled health-check. Studio reaches `healthy` in \~5–9 s.
* **No dashboard login.** `DASHBOARD_USERNAME`/`PASSWORD` were enforced by **Kong**, which we dropped. Hitting Studio directly on `:8000` is therefore **unauthenticated** — fine for localhost, but never expose that port to a network without your own reverse-proxy auth in front.
* **REST/Auth pages are inert.** Anything needing PostgREST/GoTrue (API docs, the Authentication tab) won't work — by design. `SUPABASE_URL` is pointed at `meta` only so Studio doesn't error on a dangling hostname.
* **Pin tags, never `:latest`.** Studio, meta, and Postgres versions drift; a floating tag will eventually break the health-check wiring above.

## Footprint & "scale to zero"

* **Runtime RAM ≈ 395 MB** (postgres \~64 + meta \~84 + studio \~247; both backup sidecars are single-digit MB, idle between runs). Light.
* **On disk ≈ 3.1 GB** — dominated by the Studio image (\~1.6 GB); meta \~526 MB; backup sidecar \~419 MB; `postgres:17-alpine` \~415 MB; rclone mirror \~97 MB. There is no slim Studio image and no standalone repo to build one from, so \~1.6 GB is the practical floor. _(The optional WAL-G PITR upgrade swaps the alpine DB for the \~747 MB Debian+WAL-G image; the base-backup sidecar reuses that image, \~0 extra.)_
* **No auto-suspend** like Neon's scale-to-zero. The manual equivalent is `docker compose stop` (frees all RAM, \~5 s to `start` again). You can stop just `studio` + `meta` when idle and keep `postgres` up so apps stay connected.

## Automated backups (the sidecar)

Service `4)` above is [`postgres-backup-local`](https://github.com/prodrigestivill/docker-postgres-backup-local): a tiny container that runs `pg_dump` on `SCHEDULE` and keeps a rotated history. With `BACKUP_ON_START: "TRUE"` it also dumps once immediately on `up`, so you can verify it works without waiting for the schedule.

Files land under `./backups`, already rotated for you:

```
backups/
├── last/     postgres-YYYYMMDD-HHMMSS.sql.gz   # every run
├── daily/    postgres-YYYYMMDD.sql.gz
├── weekly/   postgres-YYYYww.sql.gz
└── monthly/  postgres-YYYYMM.sql.gz            # each dir also has *-latest.sql.gz
```

**Restoring from a backup** (into a scratch DB first, to check it, then for real):

```bash
zcat backups/last/postgres-latest.sql.gz \
  | docker exec -i supastudio-db psql -U postgres -d postgres
```

> Verified: deleting a table from the live DB and then restoring the dump brought it back with its rows intact.

**Two honest limits — don't mistake this for what Neon gave you:**

* **It's local-only.** The dumps sit on the same disk as the database. If that disk dies, they die with it. To actually be safe, copy `./backups` **off-host** — e.g. `rclone` to Cloudflare R2, or a NAS mount. The sidecar makes the snapshot; getting it off the box is still on you.
* **It's snapshots, not point-in-time recovery.** You can restore to "last night", not "3:47 PM before the bad `DELETE`". Managed providers (Neon, RDS) give PITR + replication + failover; a dump cron does not. Size your expectations accordingly.

### Off-host copy to Cloudflare R2 — as a sidecar (no host cron)

Get the dumps off the box so a dead disk doesn't take the backups with it. R2 speaks the S3 API, so [`rclone`](https://rclone.org) handles it — no `wrangler` needed. And because you may not want a host `cron`/`systemd` job, service `5)` above runs the mirror **inside compose**: an `rclone` container that syncs `./backups` → R2 every `BACKUP_MIRROR_INTERVAL` seconds. It reads its R2 credentials from `.env` as `RCLONE_CONFIG_R2BACKUP_*`, so **no host `rclone.conf` is needed**.

1. Cloudflare dashboard: **R2 → Manage R2 API Tokens → Create API Token**, **Object Read & Write**, scoped to one bucket (e.g. `db-backups`). Put the **Access Key ID**, **Secret Access Key**, and **Account ID** (it's in the S3 endpoint URL) into `.env`. Done — `docker compose up -d` starts mirroring.
2.  Restore straight from R2 when needed (works from any box with the creds):

    ```bash
    rclone cat r2backup:<bucket>/supastudio/last/postgres-latest.sql.gz \
      | zcat | docker exec -i supastudio-db psql -U postgres -d postgres
    ```

**Notes / gotchas (all verified):**

* `NO_CHECK_BUCKET=true` (set in the service) is required for a **bucket-scoped token** — without it every sync throws a spurious `501 NotImplemented` on the S3 bucket-check call, then retries. With it, syncs are clean (exit 0).
* `rclone lsd r2backup:` returning **403 AccessDenied is normal** for a bucket-scoped token — it just can't _enumerate_ buckets. Target it by name.
* `--copy-links` makes the `*-latest.sql.gz` **symlinks** upload as real objects.
* Verified end to end: the sidecar pushed a marker file to R2, and a dump pulled **back** from R2 was a valid gzip with a real `pg_dump` header.

If you'd rather **not** run the mirror container, the equivalent host-side one-liner (register the remote once with `rclone config create r2backup s3 provider=Cloudflare ... no_check_bucket=true`, then) is:

```bash
rclone sync ./backups r2backup:<bucket>/supastudio --copy-links
```

Either way it's still **snapshots off-host, not PITR** — but a dead disk no longer means losing the backups. For second-granularity recovery instead of daily snapshots, see the WAL-G section below.

## Point-in-time recovery with WAL-G (optional upgrade)

The dump sidecar gives you _last night_. [**WAL-G**](https://github.com/wal-g/wal-g) gives you _any second_: Postgres continuously ships write-ahead-log segments to R2, so you can restore to "3:46:59 PM, just before the bad `DELETE`". This turns your **RPO from \~24 h into \~60 s** and is the closest a single box gets to what Neon's PITR offered. Keep the dump sidecar too — it's a dead-simple independent fallback.

It's the advanced tier: a custom image, a few settings, a base-backup sidecar, and — non-negotiable — a **tested restore**. At R2 free-tier this costs \~$0 for a small DB (WAL + base backups stay well under the 10 GB / 1M-ops free limits).

### 1. Custom Postgres image with WAL-G baked in

WAL-G ships prebuilt **glibc** binaries only, so base off Debian `postgres:17`, not alpine. (On **aarch64** use the `aarch64` asset, as below.)

```dockerfile
# pg-walg/Dockerfile
FROM postgres:17
ARG WALG_VERSION=v3.0.8
ARG WALG_ASSET=wal-g-pg-20.04-aarch64        # 20.04 = oldest glibc, safest. amd64 asset on x86.
RUN set -eux; apt-get update; apt-get install -y --no-install-recommends curl ca-certificates; \
    curl -fsSL "https://github.com/wal-g/wal-g/releases/download/${WALG_VERSION}/${WALG_ASSET}.tar.gz" -o /tmp/w.tgz; \
    tar -xzf /tmp/w.tgz -C /tmp; mv "/tmp/${WALG_ASSET}" /usr/local/bin/wal-g; chmod +x /usr/local/bin/wal-g; \
    rm /tmp/w.tgz; apt-get purge -y curl; apt-get autoremove -y; rm -rf /var/lib/apt/lists/*; wal-g --version
```

### 2. Turn on archiving + add the base-backup sidecar

Shared R2 config as a YAML anchor, the `postgres` service switched to the image with archiving flags, and a sidecar that pushes a full base backup on a timer:

```yaml
x-walg-env: &walg-env
  WALG_S3_PREFIX: ${WALG_S3_PREFIX}                 # s3://<bucket>/walg
  WALG_COMPRESSION_METHOD: lz4
  AWS_ACCESS_KEY_ID: ${R2_ACCESS_KEY_ID}
  AWS_SECRET_ACCESS_KEY: ${R2_SECRET_ACCESS_KEY}
  AWS_ENDPOINT: ${R2_ENDPOINT}
  AWS_REGION: ${AWS_REGION:-auto}
  AWS_S3_FORCE_PATH_STYLE: "true"

services:
  postgres:
    image: pg-walg:17-3.0.8
    build: ./pg-walg
    environment:
      <<: *walg-env
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    command:
      - postgres
      - -c
      - wal_level=replica
      - -c
      - archive_mode=on
      - -c
      - archive_command=wal-g wal-push %p
      - -c
      - archive_timeout=60          # force a segment (≈RPO ceiling) every 60s
    # ...healthcheck/ports/volumes as before...

  base-backup:
    image: pg-walg:17-3.0.8
    restart: unless-stopped
    depends_on: { postgres: { condition: service_healthy } }
    volumes:
      - db-data:/var/lib/postgresql/data:ro
    environment:
      <<: *walg-env
      PGHOST: postgres
      PGUSER: postgres
      PGPASSWORD: ${POSTGRES_PASSWORD}
      PGDATABASE: ${POSTGRES_DB}
      BASEBACKUP_INTERVAL: ${BASEBACKUP_INTERVAL:-21600}   # every 6h
    entrypoint:
      - /bin/bash
      - -c
      - |
        sleep 15
        while true; do
          echo "[base-backup] $(date -u) pushing...";
          wal-g backup-push /var/lib/postgresql/data && echo ok || echo "FAILED (WAL still protects you)";
          sleep "$${BASEBACKUP_INTERVAL}";
        done
```

`.env` additions (reuses the same `R2_*` creds as the mirror):

```bash
WALG_S3_PREFIX=s3://<bucket>/walg
BASEBACKUP_INTERVAL=21600
AWS_REGION=auto
```

Verify archiving is live: `psql -c "select archived_count, failed_count from pg_stat_archiver;"` — you want `failed_count = 0` and `archived_count` climbing.

### 3. Restore to a point in time (test this before you trust it!)

Restore into a **throwaway** instance first. Fetch the base backup, point recovery at a target, let Postgres replay WAL and promote:

```bash
# runs as the postgres user, in a fresh pg-walg container with the R2 env set
export PGDATA=/var/lib/postgresql/data
wal-g backup-fetch "$PGDATA" LATEST
cat >> "$PGDATA/postgresql.auto.conf" <<EOF
restore_command = 'wal-g wal-fetch %f %p'
recovery_target_time = '2026-07-21 15:46:59+00'   # or recovery_target_name = 'my_restore_point'
recovery_target_action = 'promote'
EOF
touch "$PGDATA/recovery.signal"
pg_ctl -D "$PGDATA" -w start
```

Tips: `SELECT pg_create_restore_point('label')` before risky operations gives you a named target; otherwise use `recovery_target_time`. `wal-g backup-list` shows your base backups.

> **Verified end to end:** created a row, marked a restore point, dropped the table, then restored — Postgres stopped exactly at the restore point and the table + row came back. RPO in the test was seconds.

### The one caveat that matters

**If R2 is unreachable, `archive_command` keeps failing and Postgres retains WAL in `pg_wal` until it succeeds — which can fill the disk.** Monitor it:

```sql
SELECT failed_count, last_failed_wal, last_failed_time FROM pg_stat_archiver;
```

Alert if `failed_count` climbs or `pg_wal` size grows. This — not RAM/CPU — is the real operational cost of WAL archiving.

## Migrating off Neon.tech (full walkthrough)

Move a real database off a hosted provider (Neon, Supabase cloud, RDS…) into your local Postgres, end to end. Copy-paste friendly — set the two variables first.

> You don't need Postgres installed on the host: `pg_dump`/`pg_restore` already live **inside** the `supastudio-db` container, so every command below runs through `docker exec` / `docker compose exec`. That also guarantees the client tools match the local server version.

### 0. Set your endpoints

```bash
# Source: copy the "Connection string" from the Neon dashboard (the pooled OR
# direct string both work; the direct one is slightly faster for a big dump).
NEON_URL="postgresql://USER:PASSWORD@ep-xxxx.eu-central-1.aws.neon.tech/dbname?sslmode=require"

# Target: the local container from this guide.
LOCAL_URL="postgres://postgres:postgres@localhost:5433/postgres"
```

### 1. Check the source Postgres version (avoids a restore failure)

```bash
docker exec -i supastudio-db psql "$NEON_URL" -tAc "show server_version;"
```

Your local Postgres major version must be **>= this number**. `postgres:17-alpine` covers every current Neon project; if Neon ever reports 18+, bump the image tag.

### 2. Make sure the local stack is up with an EMPTY target DB

```bash
docker compose up -d
docker exec -i supastudio-db psql "$LOCAL_URL" -c "\dt"   # expect "Did not find any relations."
```

If it isn't empty and you want a clean import, reset it:

```bash
docker exec -i supastudio-db psql "$LOCAL_URL" -c "drop schema public cascade; create schema public;"
```

### 3. Dump from Neon (schema + data + any migration-history table)

```bash
docker exec -i supastudio-db pg_dump "$NEON_URL" \
  -Fc --no-owner --no-acl -f /tmp/neon.dump

docker exec -i supastudio-db sh -c 'ls -lh /tmp/neon.dump'   # sanity: non-zero size
```

`-Fc` = compressed custom format (lets `pg_restore` parallelise). `--no-owner --no-acl` drops Neon-specific roles/grants so nothing errors on the local side.

### 4. Restore into the local container

```bash
docker exec -i supastudio-db pg_restore --no-owner --no-acl \
  -d "$LOCAL_URL" /tmp/neon.dump
```

Ignore any `role "..." does not exist` / `COMMENT ON EXTENSION` notices — those are harmless Neon-isms. Then verify the data landed:

```bash
docker exec -i supastudio-db psql "$LOCAL_URL" -c "\dt"
docker exec -i supastudio-db psql "$LOCAL_URL" -c "select count(*) from <your_biggest_table>;"
```

You can now open **http://localhost:8000** and browse the imported tables in Studio.

### 5. Repoint your application

Change the app's connection string from the Neon URL to the local one **and drop `?sslmode=require`** (the local container has no TLS; leaving it on will refuse the connection). Postgres client libraries default to `sslmode=prefer`, so no TLS param is needed:

```bash
# before
DATABASE_URL=postgresql://USER:PW@ep-xxxx.neon.tech/db?sslmode=require
# after
DATABASE_URL=postgres://postgres:postgres@localhost:5433/postgres
```

> If your app runs **inside Docker** on the same host, don't use `localhost` — put it on the same compose network and connect to the service name and internal port instead, e.g. `postgres://postgres:postgres@supastudio-db:5432/postgres`.

### 6. Verify, then decommission Neon

Start the app, hit its health endpoint, exercise a read and a write. If your app owns its migrations (sqlx / Prisma / Drizzle / Alembic…), the full dump already included the migration-history table, so it will see every migration as **already applied** and make no changes. Only once you've confirmed the app is happy on local should you delete / pause the Neon project.

### 7. (Recommended) Back up your new local DB

You no longer have a managed provider taking snapshots — schedule your own:

```bash
docker exec -i supastudio-db pg_dump "$LOCAL_URL" -Fc \
  -f "/tmp/backup-$(date +%F).dump"
docker cp supastudio-db:/tmp/backup-$(date +%F).dump ~/db-backups/
```

### Extensions caveat

Stock `postgres:*-alpine` ships only the standard contrib set (`pgcrypto`, `uuid-ossp`, `pg_trgm`, `hstore`, …). If your schema uses `pgvector`, `postgis`, `pg_cron`, etc., the restore will fail on `CREATE EXTENSION`; use an image that bundles them (e.g. `pgvector/pgvector:pg17`) or `supabase/postgres` instead. Note `gen_random_uuid()` is **core since PG 13** — it needs no extension.
