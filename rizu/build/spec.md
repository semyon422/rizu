# Rizu Build System Specification

## Goal
The build system provides a reproducible, target-aware pipeline for three independent concerns:
- preparing target dependencies,
- compiling native runtime modules,
- assembling and packaging distributable repository artifacts.

The system is optimized for local development and CI usage on Linux hosts while producing Linux, Windows, and macOS outputs.

## User Experience
- One entry point: `./rizu/build/make.lua`.
- One target command: `build_target <linux|windows|macos>`.
- Clear packaging separation:
  - `repo` assembles repository content and update metadata.
  - `package` builds archives from the assembled repository.
- Incremental behavior: already-satisfied steps are skipped through output checks.

## Architecture Decisions
### ADR-1: Build Target As Single Task Boundary
Each platform build uses `BuildTargetTask` and a validated declarative step spec. This keeps orchestration simple and target selection explicit.

### ADR-2: Action Dispatcher with Isolated Handlers
`Executor` dispatches actions to modules under `deps/actions/` instead of owning all action logic in one file. This reduces coupling and makes new action types straightforward to add.

### ADR-3: Native Modules As Declarative Steps
Native runtime modules are modeled as ordinary deps-engine steps with explicit inputs, outputs, and bin publication. This keeps the pipeline declarative end to end and avoids executor/evaluator special cases.

### ADR-4: Atomic Packaging Tasks
Packaging is split into independent tasks:
- `assemble_repo`: create repository tree and update metadata (`files.json`, `files.lua`),
- `zip_repo`: build the cross-platform zip from assembled repo,
- `package_macos`: build macOS app bundle zip from assembled repo.

This avoids duplicated side effects and makes task dependencies explicit.

## Directory Structure
- `rizu/build/make.lua`: CLI entrypoint and task registration.
- `rizu/build/tasks/`: task-level orchestration.
- `rizu/build/deps/spec/`: declarative build step definitions by target.
- `rizu/build/deps/actions/`: executor action handlers.
- `rizu/build/deps/engine/`: execution and evaluation engine.
- `rizu/build/package/`: repository assembly and packaging internals.

## Task Graph
1. `setup_host`
2. `setup_luajit_linux`, `setup_luajit_windows`
3. `setup_macos_toolchain`
4. `build_target_<target>`
5. `assemble_repo` (depends on all `build_target_*`)
6. `zip_repo`, `package_macos` (depend on `assemble_repo`)

CLI mapping:
- `repo` -> `assemble_repo`
- `package` -> `zip_repo` + `package_macos`

## Key Components
- `Loader` + target specs: validate and materialize dependency/source-build steps.
- `NativeModulesSpec`: appends declarative compile and publish steps for target-native modules (`7z`, `video`, `minacalc`, `luamidi`).
- `StepState`: centralizes required-input checks, output freshness, and step status state.
- `Executor`: executes actions using shared step-state skip checks.
- `Evaluator`: reports per-step and aggregate target status using shared step-state checks.
- `RepoBuilder`: assembles update repo contents and archives.

`video` requires FFmpeg inputs on every target. Missing FFmpeg prerequisites keep the target non-up-to-date instead of silently skipping the module build.

## Verification
- Unit tests cover config mapping, task behavior, spec validation, executor/evaluator behavior, and packaging logic.
- The expected workflow after changes is running focused tests with `./test rizu/build`.
