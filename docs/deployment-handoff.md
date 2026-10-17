# Deployment Work Handoff

## Objective

Automate deployment after each commit to a configured branch while preserving manual VDS operation. A deployment must build native modules, activate the server, publish client update files, and publish downloadable ZIPs.

The existing production flow uses the sibling `soundsphere-updater` repository manually over SSH. This branch instead has the target-aware build system under `rizu/build/` and Docker Compose server configuration.

## Agreed Direction

Deployment should consume immutable artifacts rather than update or build inside the live server directory.

The intended eventual flow is:

1. Build and test an exact commit.
2. Produce immutable server and client artifacts.
3. Stage a release on the VDS separately from persistent state.
4. Recreate only OpenResty and wait for its health check; do not restart NATS for every application commit.
5. Publish client files and ZIP pointers only after the server succeeds.
6. Retain previous releases for rollback.
7. Trigger the same VDS deployment command from CI while keeping it available for manual SSH use.

Persistent VDS configuration and state must eventually be separated from application releases: `app_config.lua`, generated Nginx configuration, `server.db`, `storages/`, `logs/`, and `temp/` must not travel in release archives.

## Implemented: Release Artifact

A new CLI command is implemented:

```bash
./rizu/build/make.lua release
```

It registers `package_release`, which depends on both client package tasks. The intended output is:

```text
build/release/<commit>/
├── server.tar.gz
├── rizu/
├── files.json
├── rizu.zip
├── rizu_macos.zip
└── release.json
```

The server archive:

- allows dirty tracked files for pre-commit workflow testing, while identifying artifacts by `HEAD`;
- exports Git-tracked source, including current submodule files;
- excludes `userdata/` and `temp/` completely;
- adds the Linux server libraries and Lua 5.1 runtime module trees explicitly;
- includes internal release metadata;
- validates required server entrypoints and runtime modules;
- rejects production configuration, databases, storage, logs, temporary files, and user data.

The outer `release.json` contains format version 1, the exact commit, UTC build time, and SHA-256/size metadata for `server.tar.gz`, `files.json`, `rizu.zip`, and `rizu_macos.zip`. Assembly happens in a commit-specific staging directory before it is moved into place.

Relevant main-repository files:

- `rizu/build/package/ReleasePackager.lua` (new)
- `rizu/build/package/ReleasePackager_test.lua` (new)
- `rizu/build/tasks/PackageReleaseTask.lua` (new)
- `rizu/build/tasks/PackageReleaseTask_test.lua` (new)
- `rizu/build/TaskRegistry.lua`
- `rizu/build/Cli.lua`
- `rizu/build/spec.md`

## Windows Needle Build Failure and Fix

The first VDS attempt reached `build_target_windows` and failed while linking `needle_runtime.dll`:

```text
undefined reference to `clock_gettime'
```

Cause: MinGW exposes `CLOCK_MONOTONIC`, causing `needle_runtime.c` to select `clock_gettime`, but the Windows target did not provide that symbol.

The fix is committed in the `aqua` submodule as `a1129a0`:

- `aqua/ai/needle/src/needle_runtime.c` uses `QueryPerformanceCounter` and `QueryPerformanceFrequency` on `_WIN32`.
- POSIX continues to use `CLOCK_MONOTONIC` when available.
- The C process clock remains the fallback.
- `aqua/ai/needle/spec.md` documents the timing invariant.

The `aqua` commit must be pushed before deployments fetch the updated main-repository submodule pointer.

## Verification Completed

- `./test rizu/build`: 56 tests passed.
- `make -C aqua/ai/needle test`: all 10 native Needle runtime tests passed on Linux.
- Tracked-source archive export smoke test passed, including recursive submodule files and exclusion of `userdata/` and `temp/`.
- A stubbed `_WIN32` compile of `needle_runtime.c` referenced `QueryPerformanceCounter`/`QueryPerformanceFrequency` and did not reference `clock_gettime`.
- `git diff --check` passed in both repositories.

The Windows target and osxcross macOS target both build successfully in this workspace. The macOS fix avoids unavailable `___cpu_model` compiler-runtime symbols by using `sysctlbyname` for AVX2/FMA detection.

## Current Worktree State

At handoff time:

- Main repository branch: `refactor2025`, commit `f173f14ce9dc0924c93cb76739d7a54a8ad46a32`.
- The local main branch reports two commits behind `origin/refactor2025`; do not pull blindly over the dirty tree.
- Aqua submodule branch: `master`, commit `785914e48ede57b94c85e52381cfcbd947cd16a5`.
- Main repository release files are ready to commit.
- Aqua Needle source/spec changes are committed as `a1129a0`.
- `userdata/ui.json` is an unrelated user-owned untracked file and must remain untouched.

Check both worktrees before changing anything:

```bash
git status --short --branch
git -C aqua status --short --branch
```

## Build Behavior

`release` traverses Linux, Windows, and macOS target tasks. Native compilation is incremental: missing or stale declared outputs rebuild, while unchanged outputs are reused. Client repositories, ZIPs, server archive, and manifests are repackaged for every release. A fresh build workspace without cached `build/`, `bin/`, and `tree/` compiles everything.

Known correctness gap: freshness is currently based primarily on input/output timestamps. A build recipe, compiler flag, or toolchain change may not invalidate a native output if source timestamps remain older. Before relying on persistent build caches for automated production deployment, add a normalized build-step/toolchain fingerprint to step freshness state, or deliberately force native rebuilds for releases.

## Atomic VDS Deployment Implemented

`./deploy.lua deploy <commit|release-directory>` and `./deploy.lua rollback [commit]` implement the manual VDS path. The deployment root separates commit-specific server releases, persistent configuration/state, and atomically published client files. Artifact checksums are validated before extraction; only OpenResty is recreated, health failure restores the prior server, and client pointers switch only after server health succeeds.

See `deploy/spec.md` for layout, invariants, setup, and operational commands.

## Immediate Next Steps

1. Push the Needle portability fix in the `aqua` repository and the main repository deployment changes.
2. In the normal `/home/semyon422/rizu` clone, initialize `server-state/` with reviewed production configuration and existing state, moving SQLite WAL/SHM sidecars together with the database while OpenResty is stopped.
3. Copy or build a release artifact on the VDS and perform a real `deploy` plus `rollback` drill.
4. Configure the download server to serve `/home/semyon422/rizu/public/current`.
5. Configure the GitHub production environment SSH secrets and perform a real push-triggered `build-deploy` plus rollback drill. Builds now run directly on the VDS, so no artifact transfer service is required.
