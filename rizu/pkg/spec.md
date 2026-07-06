## Goal

The `rizu/pkg/` module owns local package discovery, mounting, Lua path injection, package-required module loading, and package download helpers.

## User Experience

- Installed packages should be discovered from `userdata/pkg` and mounted before game systems need packaged resources.
- Packages that expose Lua modules should be available in the main thread and worker threads.

## Architecture Decisions

- `PackageManager` composes mounting, metadata loading, dependency-free Lua requiring, and package downloads.
- `PackageLoader` reads `pkg.json` metadata from mounted package roots and indexes packages by name and type.
- `PackageRequire` runs package-declared require entry points after package Lua paths are exported.

## Invariants

- Thread initialization in `main.lua` must use the same `PackageLoader`/`PackageRequire` classes as the main thread.
- Package metadata version and dependency parsing remain lightweight and local to this module.
