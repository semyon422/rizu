# Rizu Build System Specification

## Goal
The build system provides a reproducible, target-aware pipeline for three independent concerns:
- preparing target dependencies,
- compiling native runtime modules,
- assembling and packaging distributable repository artifacts.

The system is optimized for local development and CI usage on Linux hosts while producing Linux, Windows, and macOS outputs.

## User Experience
- One entry point: `./rizu/build/make.lua`.
- One target command: `build_target <linux|windows|macos>` (runs LuaJIT setup steps automatically).
- Optional `luajit <linux|windows>` to build only the LuaJIT SDK under `tree/`.
- Clear packaging separation:
  - `repo` assembles repository content and update metadata.
  - `package` builds archives from the assembled repository.
  - `release` builds a commit-addressed deployment artifact containing the server archive and client downloads.
- Incremental behavior: already-satisfied steps are skipped through output checks.

## Architecture Decisions
### ADR-1: Build Target As Single Task Boundary
Each platform build uses `BuildTargetTask` and a validated declarative step spec. This keeps orchestration simple and target selection explicit.

### ADR-2: Action Dispatcher with Isolated Handlers
`Executor` dispatches actions to modules under `deps/actions/` instead of owning all action logic in one file. This reduces coupling and makes new action types straightforward to add.

### ADR-3: Native Modules As Declarative Steps
Native runtime modules are modeled as ordinary deps-engine steps with explicit inputs, outputs, and bin publication. This keeps the pipeline declarative end to end and avoids executor/evaluator special cases. For macOS, source-built prefix dependencies are ordered before shared binary and module steps because the BASS FFmpeg plugin and video module consume the locally built FFmpeg headers and libraries.

### ADR-4: Atomic Packaging Tasks
Packaging is split into independent tasks:
- `assemble_repo`: create repository tree and update metadata (`files.json`, `files.lua`),
- `zip_repo`: build the cross-platform zip from assembled repo,
- `package_macos`: build macOS app bundle zip from assembled repo.

This avoids duplicated side effects and makes task dependencies explicit.

## Directory Structure
- `rizu/build/make.lua`: executable entrypoint.
- `rizu/build/Cli.lua`: CLI command dispatch, argument validation, status, and clean commands.
- `rizu/build/TaskRegistry.lua`: context construction and task registration.
- `rizu/build/tasks/`: task-level orchestration.
- `rizu/build/deps/spec/`: declarative build step definitions by target.
- `rizu/build/deps/spec/source/`: per-dependency source-build recipes shared by target specs.
- `rizu/build/deps/actions/`: executor action handlers.
- `rizu/build/deps/engine/`: execution and evaluation engine.
- `rizu/build/package/`: repository assembly and packaging internals.

## Task Graph
1. `setup_host`
2. `setup_macos_toolchain` (macOS builds only, via `build_target_macos`)
3. `build_target_<target>` (pulls `setup_luajit_linux` for every target; `setup_luajit_windows` for Windows)
4. `assemble_repo` (depends on all `build_target_*`)
5. `zip_repo`, `package_macos` (depend on `assemble_repo`)
6. `package_release` (depends on both client package tasks)

CLI mapping:
- `luajit` -> `setup_luajit_<linux|windows>`
- `repo` -> `assemble_repo`
- `package` -> `zip_repo` + `package_macos`
- `release` -> `package_release`

## Key Components
- `DependencySpec`: public dependency-step spec entrypoint; resolves target builders, composes native module steps, normalizes, and validates target specs. Prefetch uses the same spec but only runs download and git actions.
- `LinuxSpec`, `WindowsSpec`, and `MacosSpec`: target orchestrators that select target paths/toolchains and compose source dependency recipes.
- `deps/spec/source/*SourceSpec`: per-dependency recipes for zlib, iconv, OpenSSL, LuaSec, FFTW, SQLite, and macOS FFmpeg source builds.
- `deps/spec/common/LuaJITSpec`: declarative LuaJIT clone and install steps into `tree/`; executed by `SetupLuaJITTask`.
- `SpecNormalizer`: fills defaults and infers outputs from declarative actions.
- `SpecValidator` + `ActionSchema`: validate step shape, supported action types, required fields, and shell-action policy.
- Target specs append declarative compile and publish steps for native modules (`7z`, `video`, `minacalc`, `luamidi`, and the dependency-free Needle runtime).
- `StepState`: centralizes required-input checks, output freshness, and step status state.
- `Executor`: executes actions using shared step-state skip checks.
- `Evaluator`: reports per-step and aggregate target status using shared step-state checks.
- `RepoAssembler`, `UpdateIndexWriter`, `ZipPackager`, and `MacOSPackager`: package-stage implementations called directly by package tasks.
- `ReleasePackager`: creates `build/release/<commit>/` with `server.tar.gz`, the assembled client repository, client ZIPs, `files.json`, and a checksummed `release.json`.
- Repository assembly copies platform output directories, then removes FFmpeg shared libraries outside the pinned ABI set so stale files from earlier builds cannot enter releases.
- macOS packaging rewrites build-host Mach-O dependency paths and install IDs to `@loader_path` references, then rejects any remaining `build/deps/` dependency before creating the archive.
- `server-state/package_config.lua`: ignored deployment input that supplies the client update repository and WebSocket endpoints embedded during packaging.

## Release Artifact

`release` exports the current Git-tracked application files from the working tree into the server archive, excluding `userdata/` and `temp/`. Dirty tracked files are allowed so the complete release workflow can be tested before committing; the release directory and manifest remain keyed by `HEAD`, so such artifacts are development snapshots and must not be treated as immutable commit builds. It adds the Linux native modules required by the Compose server and the Lua 5.1 runtime module trees. Ignored local configuration, databases, storage, logs, and user data are never copied into the artifact.

The server archive contains its own release metadata. The outer `release.json` records the format version, exact Git commit, UTC build time, byte size, and SHA-256 checksum of each deployable file. Packaging validates required server entrypoints and native modules and rejects runtime state or production configuration in the archive.

Archive extraction defaults to stripping one leading path component for source releases with a top-level directory. Recipes whose upstream archives contain the desired layout at archive root must set `strip_components = 0` and declare real file outputs, not only the destination directory. When an extract action runs, it recreates the destination directory before unpacking. Tar extraction uses extraction-time mtimes so freshness reflects the local archive input rather than old upstream file timestamps stored inside the tarball.

Temporary extraction directories belong under `build/deps` unless they are final runtime outputs. macOS toolchain setup selectively streams only the requested SDK and libc++ headers out of the Xcode payload; it must not unpack the complete Xcode application because that requires substantially more temporary disk space than the release inputs.

FFTW 3.3.10 declares an obsolete CMake minimum that CMake 4 rejects before configuration. Its Linux configure action sets `CMAKE_POLICY_VERSION_MINIMUM=4.0`, explicitly opting the pinned source into CMake 4 policy behavior. CMake 4 is therefore the supported host baseline for this recipe.

`video` tracks FFmpeg headers and libraries as inputs on every target. Missing FFmpeg prerequisites keep the target non-up-to-date instead of silently skipping the module build. Linux and Windows use immutable BtbN FFmpeg 8.1.2 autobuild assets rather than the rolling `latest` aliases. Updating FFmpeg requires selecting one dated BtbN release, pinning its full asset names in `Manifest.lua`, and updating the artifact maps and Aqua FFI loader together if shared-library majors change.

## Verification
- Unit tests cover config mapping, task behavior, spec validation, executor/evaluator behavior, and packaging logic.
- The expected workflow after changes is running focused tests with `./test rizu/build`.
