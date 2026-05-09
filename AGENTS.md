# AGENTS.md

## Purpose

This is the repository-wide source of truth for AI coding assistants.

Tool-specific instruction files (for example `GEMINI.md`, `CLAUDE.md`, `.cursorrules`) should defer to this file. If another instruction file conflicts with this one, follow `AGENTS.md` unless explicitly told otherwise by the user in the current task.

## Quick Checklist

Before editing:
1. Read this file and then scan nearby module docs, especially local `spec.md` files.
2. Locate existing class names and usages before introducing new names.
3. Prefer minimal, targeted edits that preserve existing architecture and conventions.

While editing:
1. Keep namespace, class, and file naming consistent with the rules below.
2. Do not delete tests; move and update them with source changes.
3. Add or update a nearby `spec.md` for major behavior or architecture changes.

After editing:
1. Run relevant tests with `./test [file_pattern] [method_pattern]`.
2. Summarize behavior changes and list follow-up risks or TODOs.

## Change Safety Rules

- Do not perform destructive repository operations unless explicitly requested.
- Do not silently change public interfaces, persistence formats, or remote method contracts without documenting the change.
- For cross-worker, websocket, or ICC changes, verify queue encoding, whitelist entries, and context injection assumptions.
- If the worktree is already dirty, do not revert unrelated user changes.

## Project Map

- `rizu/`: modern game client and core systems. Start with `rizu/spec.md`.
- `sea/`: website, server-side logic, shared web infrastructure. Start with `sea/spec.md`.
- `aqua/`: general-purpose shared Lua infrastructure. Start with `aqua/spec.md`.
- `chartbase/`: chart parsers and format-specific loaders. See format-local specs when present.
- `sphere/`: legacy client code that is gradually being rewritten into `rizu/`. Start with `sphere/spec.md`.

Existing feature specs worth checking early:
- `rizu/build/spec.md`
- `rizu/library/spec.md`
- `rizu/select/spec.md`
- `rizu/preview/spec.md`
- `rizu/dlc/spec.md`
- `rizu/gameplay/spec.md`
- `rizu/engine/spec.md`
- `chartbase/sph/spec.md`

## Building And Running

Run the game with the bundled LÖVE launchers:
- `game-appimage`
- `game-macos`
- `game-win64.bat`

Run tests with:

```bash
./test [file_pattern] [method_pattern]
```

Examples:

```bash
./test rizu/gameplay/GameplayTimings_test.lua
./test rizu/build
```

## Code Conventions

### Lua Style

- Follow `.editorconfig`: use tabs for indentation and do not indent empty lines.
- Omit empty `:new()` constructors.
- Avoid using Lua global names like `type`, `table`, `string`, or `pairs` as locals. If needed, prefix with `_`.
- Prefer minimal comments and use EmmyLua for API documentation.

### Naming And Namespaces

- Do not derive class names only from file paths. Read the file definition or existing usages first.
- Legacy modules use `prefix.ClassName` naming such as `sea.UserConnectionsRepo`.
- Modern `rizu.*` modules use concise lowercase namespaces with PascalCase class names.
- Use semantic suffixes:
  - `Repo` for database or storage access
  - `Generator` for data transformation
  - `Task` for long-running orchestration
  - `Manager` for high-level coordination
- Filenames must match the class name.
- Interfaces are prefixed with `I`.

### Type Annotations

- Preserve and improve EmmyLua annotations when touching code.
- Prefer precise table annotations such as `{[KeyType]: ValueType}` over `table<KeyType, ValueType>`.
- Keep class annotations aligned with the actual runtime class name and namespace.
- For web resources, use the concrete class annotation pattern described in `sea/spec.md`.

## Testing Rules

- Test files are first-class and must not be deleted.
- Test files should use the `_test.lua` suffix and stay next to the source they cover.
- Always run relevant tests after making changes.
- Prefer tests that validate behavior, invariants, failure modes, and internal contracts over tests that restate implementation details.
- If a module moves or is renamed, move and update its tests too.

Test structure:
- A test file returns a table of test functions.
- Each test function receives `t` of type `testing.T`.
- Use the assertion helpers on `t` such as `eq`, `ne`, `aeq`, `tdeq`, `has_error`, and `has_not_error`.

For ICC or shared-memory communication tests:
- Use `FakeSharedDict`.
- Prefer no-return remotes for one-way inter-connection messaging.
- Assert queue payloads directly with `t:tdeq(...)`.

## Documentation Rules

- Keep documentation close to the code.
- New features or major behavior changes must be documented in a nearby `spec.md`.
- Each `spec.md` should begin with:
  - `## Goal`
  - `## User Experience`
- Significant architectural choices should be recorded in an `## Architecture Decisions` or `## ADR` section.
- Use precise terminology. For example, do not use "difficulty" when you mean chart variation or chart file.

## When To Create Or Update A Spec

Update a nearby `spec.md` when you:
- add a new subsystem or major workflow,
- change behavior that affects users or other modules,
- introduce new architectural constraints,
- formalize conventions that future agents need in that folder.

Keep root `AGENTS.md` focused on universal rules. Put feature-specific details in the closest relevant `spec.md`.
