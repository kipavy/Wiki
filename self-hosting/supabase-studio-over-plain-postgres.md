# Supabase Studio over plain Postgres (Neon-like local DB)

A lightweight, self-hosted alternative to [Neon.tech](https://neon.tech)'s console:
just the **Supabase Studio SQL editor + table editor**, pointed at an ordinary
Postgres container. No auth, Realtime, Storage, Kong, PostgREST, or
Logflare/analytics — three containers total.

Great when you want a nice web UI over a local Postgres (browsing tables, running
SQL) without paying for, or being rate-limited by, a hosted provider.

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

The whole Supabase self-hosting stack normally routes Studio → **Kong** → everything.
But for the **SQL editor and table editor specifically**, Studio talks to
`postgres-meta` **directly** via `STUDIO_PG_META_URL` — Kong never sat between
those two. So dropping Kong (and auth/realtime/storage/rest) changes nothing for
the two features we care about.

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
```

## Run

```bash
docker compose up -d
# open http://localhost:8000  ->  redirects to /project/default
```

Connect apps to the DB at `postgresql://postgres:postgres@localhost:5433/postgres`.

## Gotchas (each verified, not guessed)

* **Logflare / analytics health-check.** Older Studio tags hard-depended on the
  `analytics` (Logflare) service and never went `healthy` in a trimmed stack.
  Current tags gate it behind **`ENABLED_FEATURES_LOGS_ALL: "false"`** (set above),
  so the container's health-check (`GET /api/platform/profile`) returns `200`
  **without** any analytics service, stub, or disabled health-check. Studio reaches
  `healthy` in ~5–9 s.
* **No dashboard login.** `DASHBOARD_USERNAME`/`PASSWORD` were enforced by **Kong**,
  which we dropped. Hitting Studio directly on `:8000` is therefore
  **unauthenticated** — fine for localhost, but never expose that port to a network
  without your own reverse-proxy auth in front.
* **REST/Auth pages are inert.** Anything needing PostgREST/GoTrue (API docs, the
  Authentication tab) won't work — by design. `SUPABASE_URL` is pointed at `meta`
  only so Studio doesn't error on a dangling hostname.
* **Pin tags, never `:latest`.** Studio, meta, and Postgres versions drift; a
  floating tag will eventually break the health-check wiring above.

## Footprint & "scale to zero"

* **Runtime RAM ≈ 395 MB** (postgres ~64 + meta ~84 + studio ~247; the backup
  sidecar is ~2 MB, idle between runs). Light.
* **On disk ≈ 3.0 GB** — dominated by the Studio image (~1.6 GB); meta ~526 MB;
  backup sidecar ~419 MB; `postgres:17-alpine` ~415 MB. There is no slim Studio
  image and no standalone repo to build one from, so ~1.6 GB is the practical floor.
* **No auto-suspend** like Neon's scale-to-zero. The manual equivalent is
  `docker compose stop` (frees all RAM, ~5 s to `start` again). You can stop just
  `studio` + `meta` when idle and keep `postgres` up so apps stay connected.

## Automated backups (the sidecar)

Service `4)` above is [`postgres-backup-local`](https://github.com/prodrigestivill/docker-postgres-backup-local):
a tiny container that runs `pg_dump` on `SCHEDULE` and keeps a rotated history.
With `BACKUP_ON_START: "TRUE"` it also dumps once immediately on `up`, so you can
verify it works without waiting for the schedule.

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

> Verified: deleting a table from the live DB and then restoring the dump brought
> it back with its rows intact.

**Two honest limits — don't mistake this for what Neon gave you:**

* **It's local-only.** The dumps sit on the same disk as the database. If that disk
  dies, they die with it. To actually be safe, copy `./backups` **off-host** —
  e.g. `rclone` to Cloudflare R2, or a NAS mount. The sidecar makes the snapshot;
  getting it off the box is still on you.
* **It's snapshots, not point-in-time recovery.** You can restore to "last night",
  not "3:47 PM before the bad `DELETE`". Managed providers (Neon, RDS) give PITR +
  replication + failover; a dump cron does not. Size your expectations accordingly.

### Off-host copy to Cloudflare R2 (rclone)

Get the dumps off the box so a dead disk doesn't take the backups with it. R2 talks
the S3 API, so [`rclone`](https://rclone.org) handles it — no `wrangler` needed.

1. In the Cloudflare dashboard: **R2 → Manage R2 API Tokens → Create API Token**,
   **Object Read & Write**, scoped to one bucket (e.g. `db-backups`). Note the
   **Access Key ID**, **Secret Access Key**, and your **Account ID**.
2. Register the remote (values are yours; keep them out of shell history):

   ```bash
   rclone config create r2backup s3 provider=Cloudflare \
     access_key_id=<ACCESS_KEY_ID> \
     secret_access_key=<SECRET_ACCESS_KEY> \
     endpoint=https://<ACCOUNT_ID>.r2.cloudflarestorage.com \
     acl=private
   # Bucket-scoped tokens can't do the S3 bucket-check call; silence the retry:
   rclone config update r2backup no_check_bucket true
   ```

3. Push, and restore straight from R2 when needed:

   ```bash
   # Upload (‑‑copy-links so the *-latest.sql.gz symlinks upload as real objects)
   rclone sync ./backups r2backup:<bucket>/supastudio --copy-links

   # Restore directly from R2
   rclone cat r2backup:<bucket>/supastudio/last/postgres-latest.sql.gz \
     | zcat | docker exec -i supastudio-db psql -U postgres -d postgres
   ```

   > `rclone lsd r2backup:` returning **403 AccessDenied is normal** for a
   > bucket-scoped token — it just can't enumerate buckets. Target it by name.

4. Automate it after each dump — a cron entry (or systemd timer):

   ```cron
   # 03:30 daily, a bit after the sidecar's @daily dump
   30 3 * * * cd /path/to/supastudio-lite && rclone sync ./backups r2backup:<bucket>/supastudio --copy-links
   ```

Verified end to end: sync up, then pull a dump **back** from R2 — valid gzip, real
`pg_dump` header. It's still snapshots off-host, not PITR — but the disk dying no
longer means losing the backups.

## Migrating off Neon.tech (full walkthrough)

Move a real database off a hosted provider (Neon, Supabase cloud, RDS…) into your
local Postgres, end to end. Copy-paste friendly — set the two variables first.

> You don't need Postgres installed on the host: `pg_dump`/`pg_restore` already
> live **inside** the `supastudio-db` container, so every command below runs
> through `docker exec` / `docker compose exec`. That also guarantees the client
> tools match the local server version.

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

Your local Postgres major version must be **>= this number**. `postgres:17-alpine`
covers every current Neon project; if Neon ever reports 18+, bump the image tag.

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

`-Fc` = compressed custom format (lets `pg_restore` parallelise). `--no-owner
--no-acl` drops Neon-specific roles/grants so nothing errors on the local side.

### 4. Restore into the local container

```bash
docker exec -i supastudio-db pg_restore --no-owner --no-acl \
  -d "$LOCAL_URL" /tmp/neon.dump
```

Ignore any `role "..." does not exist` / `COMMENT ON EXTENSION` notices — those are
harmless Neon-isms. Then verify the data landed:

```bash
docker exec -i supastudio-db psql "$LOCAL_URL" -c "\dt"
docker exec -i supastudio-db psql "$LOCAL_URL" -c "select count(*) from <your_biggest_table>;"
```

You can now open **http://localhost:8000** and browse the imported tables in Studio.

### 5. Repoint your application

Change the app's connection string from the Neon URL to the local one **and drop
`?sslmode=require`** (the local container has no TLS; leaving it on will refuse the
connection). Postgres client libraries default to `sslmode=prefer`, so no TLS
param is needed:

```bash
# before
DATABASE_URL=postgresql://USER:PW@ep-xxxx.neon.tech/db?sslmode=require
# after
DATABASE_URL=postgres://postgres:postgres@localhost:5433/postgres
```

> If your app runs **inside Docker** on the same host, don't use `localhost` — put
> it on the same compose network and connect to the service name and internal port
> instead, e.g. `postgres://postgres:postgres@supastudio-db:5432/postgres`.

### 6. Verify, then decommission Neon

Start the app, hit its health endpoint, exercise a read and a write. If your app
owns its migrations (sqlx / Prisma / Drizzle / Alembic…), the full dump already
included the migration-history table, so it will see every migration as **already
applied** and make no changes. Only once you've confirmed the app is happy on local
should you delete / pause the Neon project.

### 7. (Recommended) Back up your new local DB

You no longer have a managed provider taking snapshots — schedule your own:

```bash
docker exec -i supastudio-db pg_dump "$LOCAL_URL" -Fc \
  -f "/tmp/backup-$(date +%F).dump"
docker cp supastudio-db:/tmp/backup-$(date +%F).dump ~/db-backups/
```

### Extensions caveat

Stock `postgres:*-alpine` ships only the standard contrib set (`pgcrypto`,
`uuid-ossp`, `pg_trgm`, `hstore`, …). If your schema uses `pgvector`, `postgis`,
`pg_cron`, etc., the restore will fail on `CREATE EXTENSION`; use an image that
bundles them (e.g. `pgvector/pgvector:pg17`) or `supabase/postgres` instead. Note
`gen_random_uuid()` is **core since PG 13** — it needs no extension.
