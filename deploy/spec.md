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

`build-deploy` fetches and checks out the exact requested commit in detached-HEAD state, updates recursive submodules, runs tests, builds the release locally on the VDS, and deploys it. A deployment verifies all artifact checksums, stages the server, starts or preserves NATS, recreates the compute worker and OpenResty, waits for health, and publishes client downloads only after server success. A failed candidate restores the previous OpenResty release automatically. `status` reports whether OpenResty is using an immutable release, the checkout, a host process, or is stopped, together with mounts, health, commit, and active pointers.

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
- NATS is started if absent but is not recreated for application deployments. The compute worker and OpenResty are recreated together with `--no-deps`; OpenResty depends on the compute health check during normal Compose startup.
- The compute service is a single persistent LuaJIT process bound to loopback. It mounts the immutable release read-only and has no `server-state` mount, so SQLite ingestion/finalization remains owned by OpenResty.
- The candidate OpenResty and compute processes must both become Compose-healthcheck healthy before `current` or public client files switch.
- Failed health restores the previous OpenResty release. With no previous release, the failed OpenResty service is stopped.
- Explicit and implicit rollback use the same health gate before switching server and public pointers.
- Only the current and previous server and published client releases are retained. After successful publication, all `build/release/` copies and stale staging directories are removed because deployed immutable directories are the durable rollback copies.
- `build-deploy`, `deploy`, and `rollback` acquire the same `flock` lock. Concurrent automation or operators wait up to two hours instead of racing state and service changes.
- Automated builds fetch and checkout the full pushed SHA rather than deploying a moving branch name. Tracked changes are rejected before and after checkout/submodule synchronization.

## Invariants

- Configuration, SQLite and its WAL/SHM sidecars, storage, logs, and temporary runtime files live only under `server-state/` and survive release replacement.
- Server and client pointers only identify a release that passed the OpenResty health check.
- Client publication happens after server activation, never before it.
- The deployment command does not restart NATS for each application commit.
- OpenResty and its compute worker run the same immutable release and receive the same `RIZU_COMPUTE_VERSION`; mismatched code cannot finalize a compute response.
- Release artifacts built from a dirty tree are development snapshots even though their directory is keyed by `HEAD`; production automation must consume artifacts built and tested from an exact committed revision.

## Operation

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

`.github/workflows/deploy.yml` triggers `build-deploy` over SSH for pushes to `refactor2025` and supports a manually supplied full SHA. Configure the production environment secrets:

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
