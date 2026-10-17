## Goal

Deploy immutable Soundsphere release artifacts on one VDS without mixing application source with persistent configuration or state.

## User Experience

Operators can deploy an artifact and roll back over SSH with the same commands later used by CI:

```bash
./deploy.lua build-deploy <commit>
./deploy.lua deploy <commit|release-directory>
./deploy.lua rollback [commit]
./deploy.lua status
```

`build-deploy` fetches and checks out the exact requested commit in detached-HEAD state, updates recursive submodules, runs tests, builds the release locally on the VDS, and deploys it. A deployment verifies all artifact checksums, stages the server, starts or preserves NATS, recreates the compute worker, AI router, and OpenResty, waits for health, and publishes client downloads only after server success. A failed candidate restores the previous application release automatically. `status` reports whether OpenResty is using an immutable release, the checkout, a host process, or is stopped, together with mounts, health, commit, and active pointers.

## VDS Layout

The deployment root defaults to the repository root. For the normal production clone at `/home/semyon422/rizu`, it contains:

```text
/home/semyon422/rizu/
├── current -> releases/<commit>
├── previous -> releases/<commit>
├── releases/<commit>/
├── server-state/
│   ├── app_config.lua
│   ├── bancho_config.lua
│   ├── nginx.conf
│   ├── nginx_config.lua
│   ├── package_config.lua
│   ├── server.db
│   ├── server.db-wal
│   ├── server.db-shm
│   ├── storages/
│   ├── logs/
│   └── temp/
└── public/
    ├── current -> releases/<commit>
    └── releases/<commit>/
        ├── rizu/
        ├── files.json
        ├── rizu.zip
        └── rizu_macos.zip
```

The operator must create the configuration files under `server-state/` before the first deployment. `package_config.lua` defines the client update repository and WebSocket endpoints embedded into release packages. SQLite creates `server.db` for a new installation; an existing deployment must move the database together with any `server.db-wal` and `server.db-shm` sidecars while OpenResty is stopped.

The reverse proxy or download server should serve `/home/semyon422/rizu/public/current`. Switching this symlink atomically publishes one matching set of client files and ZIPs.

## Architecture Decisions

- `release.json` format version, commit, file size, and SHA-256 values are validated before extraction or service changes.
- Server releases are extracted to a temporary directory and renamed into their commit path.
- Compose mounts the immutable candidate at `/app` and mounts the single persistent directory directly at `/app/server-state`. Application paths explicitly use `server-state/...`, so SQLite's database, WAL, and shared-memory sidecars always share one filesystem directory.
- NATS is started if absent but is not recreated for application deployments. The compute worker, AI router, and OpenResty are recreated together with `--no-deps`; OpenResty depends on the compute health check during normal Compose startup.
- The compute service is a single persistent LuaJIT process bound to loopback. It mounts the immutable release read-only and has no `server-state` mount, so SQLite ingestion/finalization remains owned by OpenResty.
- The candidate OpenResty, compute, and AI router processes must all become Compose-healthcheck healthy before `current` or public client files switch.
- Failed startup or health restores the previous application release. With no previous release, all candidate application services are stopped. Rolling back to a release without `docker/ai-router-entrypoint.sh` stops the router and checks only OpenResty and compute; router state is retained.
- Explicit and implicit rollback use the same health gate before switching server and public pointers.
- Only the current and previous server and published client releases are retained. After successful publication, all `build/release/` copies and stale staging directories are removed because deployed immutable directories are the durable rollback copies.
- `build-deploy`, `deploy`, and `rollback` acquire the same `flock` lock. Concurrent automation or operators wait up to two hours instead of racing state and service changes.
- Automated builds fetch and checkout the full pushed SHA rather than deploying a moving branch name. Tracked changes are rejected before and after checkout/submodule synchronization.

## Invariants

- Configuration, SQLite and its WAL/SHM sidecars, storage, logs, and temporary runtime files live only under `server-state/` and survive release replacement.
- Server and client pointers only identify a release that passed all applicable application health checks.
- Client publication happens after server activation, never before it.
- The deployment command does not restart NATS for each application commit.
- OpenResty and its compute worker run the same immutable release and receive the same `RIZU_COMPUTE_VERSION`; mismatched code cannot finalize a compute response.
- The AI router loads bundled SQLite and OpenSSL through symlinks in its private `/tmp/rizu-router-libs` directory, prepended to `LD_LIBRARY_PATH` before any LuaSec/FFI load. Only `libsqlite3.so`, `libssl.so.3`, and `libcrypto.so.3` are selected; do not prepend the whole game `bin` directory or replace OpenResty's own libraries. Startup fails if required files are absent or loaded SQLite/OpenSSL versions differ from the pinned build versions. The router must not silently fall back to the image's OpenSSL: different TLS ClientHello defaults can trigger upstream Cloudflare challenges. TLS peer/CA verification stays enabled, without a forced protocol downgrade. No production configuration or database migration is required for this runtime-library update.
- Release artifacts built from a dirty tree are development snapshots even though their directory is keyed by `HEAD`; production automation must consume artifacts built and tested from an exact committed revision.

## Operation

### AI Router Preparation

Before deploying a revision that includes the router, run `make ai-router-config` on the target host. This creates `server-state/ai-router/` with mode 0700, a private `config.lua` containing random admin/MCP secrets, and a private `network.lua` returning `{}` (direct networking). Existing files are preserved. Review these files and configure SOCKS5 there if required; production files are ignored and are not installed by CI.

The router mounts only this state directory at `/router-state`, separately from its read-only release at `/app`. Its config must use `db_path = "/router-state/router.db"` and `network_path = "/router-state/network.lua"`. The host directory must be writable by the deployment UID/GID. SQLite, WAL/SHM files, channel API keys, and OAuth credentials remain in this private directory across deployments. A fresh schema-8 database is created on first start; channels, users, and grants are configured through MCP.

To preserve an existing router, stop its writer and make a verified SQLite backup before installing a consistent schema-8 database as `server-state/ai-router/router.db`, owned by the deployment UID/GID with mode 0600. Never copy a live main database without accounting for WAL. Do not overwrite existing state or copy developer credentials implicitly. Older schemas require a separate backed-up manual conversion before deployment; startup does not migrate them. Rollback does not restore or convert the database.

The inference API/read-only dashboard and authenticated `/mcp` share `127.0.0.1:28083`; no separate MCP listener is opened. Remove obsolete `mcp_host`/`mcp_port` fields from production `server-state/ai-router/config.lua`, preserving secrets and state paths. Compose uses host networking, but validation prohibits public binds. An HTTPS reverse proxy forwarding all paths (such as `ai.dfjk.ru`) exposes MCP at `/mcp` too; its independent bearer token remains mandatory and browser Origin requests are rejected. SSH tunneling is also supported. Health checks verify an unauthenticated API rejection and authenticated MCP initialization without provider inference or quota consumption. Logs use Docker stdout/stderr (`make ai-router-logs`), not the developer's userdata log.

The existing off-host backup script covers the game database/storage only, **not** router state. Arrange a separate private SQLite/config backup before relying on the router in production; its database and config contain plaintext secrets.

Clone the repository at `/home/semyon422/rizu`, enter it, and prepare state once using existing production files or reviewed templates:

```bash
cd /home/semyon422/rizu
mkdir -p server-state
cp /old/deployment/server-state/app_config.lua server-state/
cp /old/deployment/server-state/bancho_config.lua server-state/
cp /old/deployment/server-state/package_config.lua server-state/
cp /old/deployment/server-state/nginx.conf server-state/
cp /old/deployment/server-state/nginx_config.lua server-state/
```

Build, test, and deploy an exact commit on the VDS:

```bash
./deploy.lua build-deploy <full-commit-sha>
```

`RIZU_DEPLOY_TEST_COMMAND` may select a different VDS test command; its default is the complete `./test` suite.

Deploy a locally available release:

```bash
./deploy.lua deploy <commit>
```

Or deploy an artifact directory copied to the VDS:

```bash
./deploy.lua deploy /path/to/release/<commit>
```

Inspect how the server was started:

```bash
./deploy.lua status
```

Rollback to the recorded previous release or a retained commit:

```bash
./deploy.lua rollback
./deploy.lua rollback <commit>
```

Use `RIZU_DEPLOY_ROOT` only for a nonstandard deployment root. Use `RIZU_COMPOSE`, `RIZU_COMPOSE_FILE`, `RIZU_ARTIFACT_ROOT`, `RIZU_HEALTH_ATTEMPTS`, and `RIZU_HEALTH_INTERVAL` to override other operational defaults. The container entrypoint exposes the mounted configuration to Aqua through the generic `NGINX_CONFIG_PATH` environment variable.

## GitHub Actions

`.github/workflows/deploy.yml` triggers `build-deploy` over SSH for pushes to `master` and supports a manually supplied full SHA. Configure the production environment secrets:

- `DEPLOY_HOST`
- `DEPLOY_USER`
- `DEPLOY_SSH_KEY` — private key used only for deployment
- `DEPLOY_HOST_KEY` — pinned known-hosts line, not an unverified runtime scan

The VDS clone must be `/home/semyon422/rizu`, have its build toolchains and ignored `server-state/`, and permit the deployment user to run Docker. GitHub concurrency serializes workflow runs. The VDS lock also protects manual operations; an overlapping deployment waits for the active deployment for up to two hours instead of failing immediately.

## Backups

Persistent data is backed up daily to a home PC reachable over Tailscale. `scripts/backup` reads ignored `server-state/backup.env`, creates a transactionally consistent SQLite snapshot with `VACUUM INTO`, verifies it with `PRAGMA integrity_check`, and transfers it atomically over pinned-host-key SSH. Seven dated database snapshots are retained.

Chart and replay storages are content-addressed and immutable after creation. They are synchronized with `rsync --ignore-existing`, so daily runs transfer only new objects and never rewrite existing backup objects. Runtime configuration, secrets, logs, temporary files, releases, and build outputs are excluded.

Install the timer on the VDS after copying `scripts/backup.example.env` to `server-state/backup.env`, creating a dedicated SSH key, pinning the home PC host key, and authorizing that key on the home PC:

```bash
sudo install -m 0644 scripts/systemd/rizu-backup.service /etc/systemd/system/
sudo install -m 0644 scripts/systemd/rizu-backup.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now rizu-backup.timer
```

The timer runs at 14:00 Asia/Yekaterinburg regardless of the VDS system timezone. `Persistent=true` runs a missed backup after the VDS restarts, but the home PC must be online when the transfer is attempted. Inspect runs with `systemctl status rizu-backup.service` and `journalctl -u rizu-backup.service`.

Restore into a staging directory first. Verify a restored database before replacing live state:

```bash
./luajit -e 'local db = require("ljsqlite3").open("/path/to/restored/server.db"); assert(db:rowexec("PRAGMA integrity_check") == "ok"); db:close()'
```

Stop OpenResty before replacing `server-state/server.db`; remove obsolete WAL/SHM sidecars, install the verified database, restore required storage objects, and start OpenResty again. Perform a test restore periodically.

## Future Work and Open Questions

- Perform a real push-triggered deployment and rollback drill before treating automation as production-ready.
- Restrict the SSH key at the server after the command contract stabilizes.
