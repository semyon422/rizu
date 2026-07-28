# Project Overview

## Goal

This file records repository-level notes that do not clearly belong to a single module. Detailed behavior and architecture should stay in the closest module `spec.md`.

## User Experience

- Players should see the project as one coherent game and online experience, even though the implementation is split across `rizu/`, `sea/`, `chart/`, `aqua/`, and legacy `sphere/`.
- Developers should use this file only for cross-project notes, entry-point concerns, and ideas that have not settled into a module yet.

## Entry Points

- `main.lua` is the top-level LÖVE startup entry point and should stay thin. Move feature behavior into the owning module spec and implementation instead of growing project-wide logic here.
- Server and tool entry points are documented near their owning modules or root configuration files.

## Future Work and Open Questions

- Use this section for quick project-wide thoughts before they have a clear owner.
- **Thin `main.lua` startup**: Keep `main.lua` as a small LÖVE entry point and gradually move startup responsibilities into named modules. Good first targets are explicit startup-argument parsing for `cli`/`debug`/`test`, a dedicated LÖVE test runner module, platform path/bootstrap handling, decorator setup, the `love.run` handoff into `rizu.loop.Loop`, and thread/package initialization. The `_G` new-global guard should remain enabled during normal startup.
- **Local online server**: Explore a future local/LAN server that provides online features without relying on the public server. It should integrate with the client database and chart storage so local hosting does not require duplicating chart files or other local data.
- Move notes into a nearby module `spec.md` once the owning subsystem becomes clear.
