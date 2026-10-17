# Project Overview

## Goal

This file records repository-level notes that do not clearly belong to a single module. Detailed behavior and architecture should stay in the closest module `spec.md`.

## User Experience

- Players should see the project as one coherent game and online experience, even though the implementation is split across `rizu/`, `sea/`, `chart/`, `aqua/`, and legacy `sphere/`.
- Developers should use this file only for cross-project notes, entry-point concerns, and ideas that have not settled into a module yet.

## Entry Points

- `main.lua` is the top-level LÖVE startup entry point and should stay thin. Move feature behavior into the owning module spec and implementation instead of growing project-wide logic here.
- Server and tool entry points are documented near their owning modules or root configuration files.

## Module Path Invariants

- Project game, worker, CLI, test, benchmark, and LuaJIT entry points use `require("pkg_config")` for common Lua and native module paths. Do not copy path lists into entry points or restore the obsolete `ncdk`, `chartbase`, and `libchart` package roots.
- `pkg_config.lua` exports Lua paths and platform-specific native paths, and exports LÖVE paths only when `love.filesystem` is available. When `OR_ROOT` is set, it also adds OpenResty's `lualib` directory.
- Entry points run from the repository root. Environment-specific imports, such as `pkg.import_lua()` in the Sea CLI, happen before loading the common config so those paths are retained.
- Standalone `aqua/env` bootstrap modules remain independent of project configuration. Thread path propagation and dynamic package loading retain their own `aqua.pkg` operations.

## Future Work and Open Questions

- Use this section for quick project-wide thoughts before they have a clear owner.
- **Thin `main.lua` startup**: Keep `main.lua` as a small LÖVE entry point and gradually move startup responsibilities into named modules. Good first targets are explicit startup-argument parsing for `cli`/`debug`/`test`, a dedicated LÖVE test runner module, platform path/bootstrap handling, decorator setup, the `love.run` handoff into `rizu.loop.Loop`, and thread/package initialization. The `_G` new-global guard should remain enabled during normal startup.
- **Local online server**: Explore a future local/LAN server that provides online features without relying on the public server. It should integrate with the client database and chart storage so local hosting does not require duplicating chart files or other local data.
- Move notes into a nearby module `spec.md` once the owning subsystem becomes clear.
