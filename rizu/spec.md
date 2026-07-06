# Rizu Module Overview

## Goal
The `rizu/` tree contains the modern implementation of the game client. It should be the default home for new gameplay, library, preview, loop, and engine work, with clear module boundaries and naming that support long-term replacement of legacy `sphere/` code.

## User Experience
- Players should experience a responsive game client with clear transitions between library browsing, previewing, and gameplay.
- New systems added under `rizu/` should integrate cleanly with the existing selection, preview, and session flow without legacy-style coupling.
- Developers should be able to work feature-by-feature by reading a nearby `spec.md` instead of learning the entire client at once.

## Directory Guide

- `engine/`: low-level engine, audio, timing, and rendering primitives. See `rizu/engine/spec.md`.
- `gameplay/`: high-level single-attempt gameplay orchestration. See `rizu/gameplay/spec.md`.
- `library/`: local chart database and navigation model. See `rizu/library/spec.md`.
- `select/`: song selection state and list synchronization. See `rizu/select/spec.md`.
- `preview/`: preview generation and synchronized playback. See `rizu/preview/spec.md`.
- `online/`: client online state, websocket connection management, and online remotes. See `rizu/online/spec.md`.
- `build/`: build and packaging pipeline. See `rizu/build/spec.md`.
- `dlc/`: downloadable content workflows. See `rizu/dlc/spec.md`.
- `loop/`, `files/`, `game/`, `input/`: supporting modules that coordinate runtime state, filesystem abstractions, top-level game setup, and input.

## Naming Conventions

- Use `rizu.<feature>` as the module prefix rather than mirroring the full directory path.
- Class names should match the PascalCase filename.
- Interfaces use an `I` prefix.
- Prefer semantic role suffixes such as `Repo`, `Generator`, `Task`, and `Manager`.

## Architecture Notes

- Favor explicit module boundaries. Low-level engine concerns belong in `rizu.engine`; user-flow orchestration belongs in higher-level modules such as `rizu.gameplay`, `rizu.select`, and `rizu.preview`.
- Keep new work in `rizu/` unless the task is clearly a legacy maintenance change in `sphere/`.
- When behavior spans multiple `rizu` modules, update the closest owning specs rather than pushing feature detail back into root docs.

## Performance And Verification

- Performance-sensitive gameplay or engine changes should be validated with focused benchmarks when appropriate, ideally via isolated `luajit` scripts that the JIT cannot trivially optimize away.
- Run focused tests with `./test` after changes, using the narrowest relevant module path.
