# Chart Editor (`rizu.editor`)

## Goal
The chart editor provides tools for creating, modifying, and exporting rhythm game charts. It reuses the game engine's audio, timing, and rendering systems so that editing a chart feels like playing it — the same skin, the same playback, the same timing model.

## User Experience
- Opening a chart in the editor loads its audio, waveform, notes, and timing data immediately. Playback, scrolling, and note editing stay synchronized to a single timeline.
- Adding, moving, or deleting notes feels responsive. Grab-and-drag works for both notes and timing vertices. Snap grid ensures notes land on musically meaningful positions.
- Undo/redo covers all note mutations. Copy, cut, paste, and flip/mirror operate on the current selection.
- Charts save as `.sph` by default and can export to `.osu`.
- Tempo and offset can be auto-detected from the audio using the NCBT algorithm.
- A scrollbar with a note density graph and waveform view lets the user navigate long charts quickly.

## Current State
The editor is functional but carries legacy code migrated from the `sphere` namespace. The core note, timing, selection, scrolling, load/save, and update-loop paths now have focused regression coverage and are being modernized incrementally. BMS-specific export features are experimental and intentionally deferred until the planned parser rewrite.

## Architecture Decisions

### ADR: Reuse Game Engine Audio And Timing
- **Context**: The editor needs accurate playback, waveform rendering, and interval-based timing — all of which the gameplay engine already provides.
- **Decision**: The editor uses `rizu.engine.audio.Engine` for playback and waveform generation, and the `ncdk` interval timing model for the timeline. No separate audio or timing subsystem is introduced.
- **Consequence**: Editor playback matches gameplay playback exactly. Changes to the audio backend or timing model propagate to the editor automatically.

### ADR: Model-Controller With Sub-Managers
- **Context**: The editor coordinates audio, notes, timing vertices, selection, undo/redo, scrolling, and UI overlays.
- **Decision**: `EditorModel` owns all sub-managers and the chart data. `EditorController` handles load/save, file operations, and format conversion. Sub-managers each own a narrow concern (notes, intervals, scrolling, graphs, undo/redo).
- **Consequence**: The update loop is centralized in `EditorModel:update()`. Each sub-manager can be tested or replaced independently.

### ADR: Interval-Based Timing Only
- **Context**: The underlying `ncdk` library supports multiple timing models. The editor currently uses only the "interval" model.
- **Decision**: The timeline is always divided into intervals by vertices. Users split segments (add a vertex), merge segments (remove a vertex), or drag vertices to adjust timing. Vertex order cannot be changed by dragging.
- **Consequence**: The editor does not support absolute or other timing models. Adding a new model requires changes across `IntervalManager`, the layer system, and the `ncdk` bindings.

### ADR: Single-Layer Editing
- **Context**: Multi-layer charts exist in some formats but the editor currently handles only one layer.
- **Decision**: One layer is loaded and edited at a time.
- **Consequence**: Editing multi-layer charts requires opening each layer separately. A future redesign may add multi-layer support.

## Core Components

### `EditorModel` — Central State
Owns the chart data (`layer`, `notes`, `chart`, `chartmeta`), all sub-managers, and the main update loop. Coordinates playback, scrolling, note rendering, and undo/redo state. Delegates per-session mutable state to `EditorSession`.

`load()` delegates lifecycle sequencing to `EditorLoadService`; `update()` is split into named substeps so behavior can be tested without running the full client. Keep orchestration changes covered by `EditorLoadService_test.lua` and `EditorModel_test.lua`. Load currently sets `loaded = true` before running substeps and fails fast if a substep errors.

`loadResources()` keeps the model-level loaded gate, then delegates audio resource loading, waveform rendering, and graph generation to `EditorResourceLoadService`. The service marks `resourcesLoaded = true` only after all three steps finish, so audio or graph failures leave the editor in the not-ready resource state.

Lifecycle fields such as `loaded`, `resourcesLoaded`, `visual`, `wave`, and `changes` are owned by `EditorRuntimeState`. Access them through `EditorModel` methods such as `isLoaded()`, `isResourcesLoaded()`, `getVisual()`, `getWave()`, and `getChanges()`; do not add raw mirror fields back to `EditorModel`.

`EditorModel` takes a dependency table rather than positional constructor arguments. Input-derived decisions should enter through injected predicates or event data. Runtime keyboard, mouse, and rectangle-selection UI calls live in `EditorInput`; model tests can inject plain functions or fake inputs instead of depending on `love.graphics`, `love.mouse`, `love.keyboard`, or `just`. Editor-view modifier checks such as command hotkeys, fine scrolling, snap changes, and speed changes should be named `EditorInput` queries exposed through `EditorModel`, not direct `love.keyboard` reads in views.

Manager ownership is attached explicitly in `attachManagers()`. Do not restore broad table mutation such as iterating over every `EditorModel` field; config, resource, input, metadata, timer, audio, and session objects must not accidentally receive `editorModel` back-references. Constructor dependencies may inject manager instances for focused tests, while production continues to use the default manager classes.

### `EditorSession` — Per-Session Mutable State
Holds state that changes during an active editing session:
- `point`: current timeline position
- `noteSkin`: loaded note skin reference
- `selectRect`, `selectStartTime`: rectangle selection state
- `patterns_analyzed`: pattern analysis results

Separated from `EditorModel` so that session-scoped data does not leak into the core model.

### `EditorViewState` — Per-Screen UI State
Holds editor UI state that should not live in chart/session state:
- `overlayState`: current overlay tab
- `dragging`: transient UI drag state used by scrollbar and snap-grid interactions

View services should mutate `EditorViewState` rather than adding UI-only fields to `EditorSession` or `EditorModel`.

### `EditorController` — Load/Save/Export
Orchestrates chart loading via `ChartSelector`, saves to `.sph` through `ChartEncoder`, and handles export formats (`.osu`, NanoChart). Delegates NanoChart and BMS-specific exports to dedicated modules in `exports/`.

The load/save boundary is tested with fakes for chart selection, note skin loading, resource lookup, file writes, and library recomputation. Resource path ordering is centralized in `getResourcePaths()`. Editor-owned file writes go through `fs.IFilesystem` instead of direct `love.filesystem` calls.

Modifier application on load is driven by an injected predicate so `EditorController` does not read keyboard state directly. Dropped audio imports are delegated to `EditorDropImport`, which owns extension filtering and writes imported files through `fs.IFilesystem`.

`EditorController` takes a dependency table rather than a long positional constructor. Keep new controller collaborators in that table to avoid argument-order bugs.

`exports/SphChartSaver` owns default `.sph` save behavior and library recomputation. `exports/OsuChartExporter` owns `.osu` export file generation. Both write through `fs.IFilesystem` and have focused tests for write failures.

`exports/NanoChartExporter` owns `.nanochart`, compressed `.nanochart`, and SPH preview file generation. It reads notes from the current `chart.Chart` model after `EditorModel:save()` and writes through `fs.IFilesystem`; do not revive legacy `editorModel.noteChart` usage.

### `VisualEngine` — Note Rendering And Selection
Maintains the pool of visible `EditorNote` wrappers. Each frame it iterates linked notes in the visible time range, creates or reuses note objects, and tracks selection state. Uses `EditorNoteFactory` to produce the correct note subclass.

Selection state is keyed by the note's current `startNote`. Drag operations that clone notes must update selection keys to avoid stale selected notes after visual refresh.

### `NoteManager` — Note Manipulation
Handles adding, removing, copying, pasting, flipping, and grab/drag operations on notes. All mutations are recorded through `EditorChanges` for undo/redo support.

### `IntervalManager` — Timing Vertex Manipulation
Split, merge, grab, and drop timing vertices on the interval timeline. Delegates to the `ncdk` layer system for the actual vertex data.

Shrinking an interval can remove chartedit points and the visual points/notes anchored to them. `IntervalManager` captures those removed points through `IntervalUpdateSnapshot` before applying the timing mutation so undo/redo can restore or remove both points and notes consistently.

### `Scroller` — Timeline Navigation
Scroll by seconds or snap grid units. Respects vertex boundaries and the current snap resolution.

Session point writes go through `EditorModel:setSessionPoint()` so timeline state updates have one owner.

### `GraphsGenerator` — Scrollbar Visualization
Generates a note density graph and a vertex graph for the scrollbar UI.

### `EditorChanges` — Undo/Redo
Wraps the generic `Changes` system with method-call commands. Records add/remove note operations with corresponding redo and undo pairs.

### `TimeManager` — Playback Timer
Extends `rizu.engine.time.LocalTimer`. Controls play/pause and current playback position.

### `Metronome` — Click Track
Provides a metronome click synced to the current timing data.

Loads its click sample through `fs.IFilesystem` so editor model tests do not depend on `love.filesystem`.

### `NcbtContext` — Tempo And Offset Detection
Runs the NCBT algorithm on the audio waveform to detect tempo and offset. Results can be applied to the chart's interval data.

### `BmsToolsContext` — BMS State Container
Holds BMS-specific editing state (`offset`, `tempo`, `beat_offset`) and provides `resetOffsetTempo()` to apply those values to the chart's layer vertices. Separated from `EditorModel` to isolate BMS-specific concerns.

## Note Types

| Note type | Editor class | Visual type |
|-----------|-------------|-------------|
| tap | `ShortEditorNote` | ShortNote |
| hold | `LongEditorNote` | LongNote |
| laser | `LongEditorNote` | LongNote |
| drumroll | `LongEditorNote` | LongNote |
| mine / shade / fake / sample | `ShortEditorNote` | SoundNote |

`ShortEditorNote` handles single-point notes. `LongEditorNote` handles head-tail pairs and supports grabbing by head, tail, or body. Both inherit from `EditorNote` and compose with the visual note classes from `rizu.engine.visual`.

## Chart Formats

- **Load**: Any format supported by the `ncdk` chart loaders (`.sph`, `.osu`, BMS-family formats).
- **Save**: `.sph` (default, via `ChartEncoder`).
- **Export**: `.osu` (via `OsuChartEncoder`), NanoChart files, BMS template (`.bme`), iBMSC clipboard data.

Editor note objects may carry runtime-only links such as `startNote` and `endNote` for manipulation. Save/conversion code must strip those links before inserting notes into the chart model.

## BMS-Specific Features (Experimental)

These features are experimental and planned for a full redesign after the parser rewrite. Do not spend modernization effort here unless a targeted bug blocks core editor work. Their logic is isolated in `rizu/editor/exports/`:

### `exports/BmsKeysoundSlicer`
Renders the full audio waveform, slices samples at note boundaries, and writes `.wav` files alongside the chart.

### `exports/BmsTemplateExporter`
Generates a `.bme` template from stem charts and their associated hitsounds. Supports 5K, 7K, and 10K column layouts.

### `exports/UbmscExporter`
Maps editor notes to iBMSC clipboard format columns and writes the output file.

## UI Layer (`ui/views/EditorView/`)

The editor is opened through the new `yi/layers/ChartMenus/Editor` screen only. The old `ui/views/EditorView.lua` screen was removed; keep `ui/views/EditorView/` as shared view modules used by the `yi` screen, not as a standalone legacy entry point.

The editor UI is composed of separate view modules:
- `Foreground`: main note display and playfield.
- `WaveformView`: audio waveform visualization.
- `SnapGridView`: snap grid overlay.
- `Footer`: status bar and controls.
- `ChartSlider`: scrollbar with note density graph.
- `OnsetsView` / `OnsetsDistView`: NCBT onset detection display.
- `EditorViewOverlay`: menus, tool selection, and configuration panels.
- `Layout`: view composition and sizing.

Views should read lifecycle/resource state through `EditorModel` accessors instead of raw fields. Rendering code may still call LÖVE and `just` directly, but model readiness, waveform, visual access, modifier state, and small UI mutations should stay behind model or service methods so runtime state does not drift into ad hoc fields.

Foreground hotkeys are dispatched through `EditorActionService`; views pass key state into the service instead of owning command behavior. Snap-grid scroll and drag behavior is owned by `EditorScrollInputService`, including fine-scroll speed override, pause/resume while dragging, snap changes, and speed changes. Overlay-only actions such as preview time, comments, selected-note commands, and BMS offset/tempo controls live in `EditorOverlayActionService` rather than `EditorModel`.

The active `yi/layers/ChartMenus/Editor` screen delegates enter/exit sequencing to `EditorScreenLoadService`. The service owns loading flags, editor controller load/unload, snap-grid construction, note-skin transforms, and sequence view load/unload so partial-load failures clear `loading` instead of leaving the screen stuck.

`EditorScreenLoadService` also creates `EditorViewServices`, the per-screen bundle for editor view collaborators. Views should use `self.editorViewServices.actionService`, `overlayActionService`, and `scrollInputService` rather than constructing module-local services. This keeps stateful view behavior reset with screen load/unload and makes future view tests injectable.

Per-frame screen sequencing lives in `EditorScreenFrameService`. It owns loaded gating and order for update, draw, and event receive; the `yi` screen should stay a thin delegator except for screen-navigation key handling.

## Configuration

Editor settings are stored through `sphere.ConfigModel` under `settings.editor`:
- `speed`: timeline scroll speed (exposed as log2 scale in UI).
- `snap`: snap grid resolution (1–192).
- `tool`: active tool (`Select`, `ShortNote`, `LongNote`, `SoundNote`).
- `lockSnap`: when true, grabbed notes snap to the grid during drag.

## Verification

- Run focused tests with `./test rizu/editor` after changes.
- Validate note mutations (add, remove, copy, paste, flip) and undo/redo behavior.
- When modifying interval or timing logic, also verify that `ncdk`-level tests pass.

## Modernization Status

Covered and partially modernized:
- Note classes and note operations, including long-note paste links, drag, cut/copy/paste, and multi-selection undo/redo.
- Interval timing operations, including split/merge/update, destructive shrink snapshots, note restoration, and vertex drag undo/redo.
- Visual selection refresh, scroller/session interaction, editor model load/update lifecycle, and note chart load/save roundtrips.
- `EditorController` load/save wiring for note skin, resources, file writes, and library recomputation.
- Resource-load sequencing and lifecycle state ownership through `EditorResourceLoadService` and `EditorRuntimeState`.
- Editor view command, overlay action, and snap-grid scroll behavior through focused services.
- Editor screen enter/exit lifecycle through `EditorScreenLoadService`.
- Editor view service ownership through `EditorViewServices`.
- Editor screen update/draw/receive sequencing through `EditorScreenFrameService`.

Remaining higher-risk areas:
- Graph generation with real charts/audio and waveform/audio resource failure modes beyond service sequencing.
- UI view integration under `ui/views/EditorView/`.
- BMS-specific exporters, intentionally deferred until parser rewrite work.
