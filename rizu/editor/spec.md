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

### ADR: Model-Controller With Services
- **Context**: The editor coordinates audio, notes, timing vertices, selection, undo/redo, scrolling, and UI overlays.
- **Decision**: `EditorModel` owns chart data and update-loop orchestration. `EditorServices` owns default construction and attachment of editor collaborators. `EditorController` handles load/save, file operations, and format conversion. Services each own a narrow concern (notes, intervals, scrolling, graphs, undo/redo).
- **Consequence**: The update loop remains centralized in `EditorModel:update()`, while collaborator wiring lives in a focused composition object. Each service can be tested or replaced independently.

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
Owns the chart data (`layer`, `notes`, `chart`, `chartmeta`) and the main update loop. Coordinates playback, scrolling, note rendering, and undo/redo state through services. Mutable editor state is split into focused state objects instead of a shared session bag.

`load()` delegates lifecycle sequencing to `EditorLoadService` through an explicit load context; `update()` is split into named substeps so behavior can be tested without running the full client. Keep orchestration changes covered by `EditorLoadService_test.lua` and `EditorModel_test.lua`. Load currently sets `loaded = true` before running substeps and fails fast if a substep errors.

`loadResources()` keeps the model-level loaded gate, then delegates audio resource loading, waveform rendering, and graph generation to `EditorResourceLoadService` through a narrow resource-load context. The service marks `resourcesLoaded = true` only after all three steps finish, so audio or graph failures leave the editor in the not-ready resource state.

`EditorModel` keeps service adapter context factories grouped near `load()`: load, session reset, resource loading, and rectangle selection. Add new model-to-service contexts there rather than inlining callback tables inside orchestration methods.

Lifecycle fields such as `loaded`, `resourcesLoaded`, `visual`, `wave`, and `changes` are owned by `EditorRuntimeState`. Access them through `EditorModel` methods such as `isLoaded()`, `isResourcesLoaded()`, `getVisual()`, `getWave()`, and `getChanges()`; do not add raw mirror fields back to `EditorModel`.

The current timeline position is owned by `EditorCursorState`. Use `EditorModel:getPoint()`, `getSessionTime()`, `setSessionPoint()`, and `setSessionTime()`.

Rectangle-selection drag state is owned by `EditorSelectionState`. Use `EditorModel:selectStart()`, `selectEnd()`, and `updateSelectionRect()`.

The loaded note skin is owned by `EditorRenderState`. Use `EditorModel:setNoteSkin()` and `getNoteSkin()`.

Pattern-analysis display text is owned by `EditorAnalysisState`. Use `EditorModel:analyzePatterns()` and `getPatternsAnalyzed()`.

`EditorModel` takes a dependency table rather than positional constructor arguments. Input-derived decisions should enter through injected predicates or event data. Runtime keyboard, mouse, and rectangle-selection UI calls live in `EditorInput`; model tests can inject plain functions or fake inputs instead of depending on `love.graphics`, `love.mouse`, `love.keyboard`, or `just`. Editor-view modifier checks such as command hotkeys, fine scrolling, snap changes, and speed changes should be named `EditorInput` queries exposed through `EditorModel`, not direct `love.keyboard` reads in views.

### `EditorServices` — Model Composition
Owns default construction of editor collaborators and copies them onto `EditorModel` for compatibility with existing callers. New model-level collaborators should be added to `EditorServices` first, then exposed on `EditorModel` only when current callers still need a direct field.

`EditorServices:attachEditorModel(editorModel)` attaches ownership explicitly. Do not restore broad table mutation such as iterating over every `EditorModel` field; config, resource, input, metadata, timer, audio, and state objects must not accidentally receive `editorModel` back-references. Constructor dependencies may still inject service instances for focused tests, while production uses the default service classes through `EditorServices`.

`EditorServices:update()` owns the per-frame service tick for note dragging and metronome updates. Keep broader chart, timing, audio, cursor, and visual update ordering in `EditorModel:update()`.

### Removed Session Bag
`EditorModel.session` has been removed as a state bag. Do not add it back. Prefer `EditorCursorState`, `EditorSelectionState`, `EditorRenderState`, `EditorAnalysisState`, `EditorRuntimeState`, or `EditorViewState` depending on ownership.

`EditorSessionResetService` owns load-time session reset orchestration through an explicit reset context: pattern analysis, undo history reset, graph generator load, resource-ready reset, cursor reset, and selection cleanup.

`EditorPlaybackService` owns timer/audio coordination: timer loading, audio settings loading, exact seek updates, audio resource loading, play/pause, and audio updates. It receives explicit timer, audio engine, chart, audio settings, and interval-grab dependencies rather than the whole `EditorModel`; keep playback behavior behind `EditorModel` wrappers so existing callers do not reach into the service directly unless they are focused tests.

`EditorSelectionService` owns selection actions: note selection, rectangle-selection lifecycle, and rectangle-selection updates. It pairs with `EditorSelectionState` through a narrow rectangle-selection context; `EditorModel` keeps wrapper methods for callers.

`EditorSettingsService` owns editor/audio settings helpers: editor settings normalization, log speed, snap increment/decrement, and snap display bucket calculation. It operates on `ConfigModel` or the concrete `settings.editor` table rather than receiving the whole `EditorModel`; keep snap/speed mutation rules here rather than scattering them through view code.

### `EditorViewState` — Per-Screen UI State
Holds editor UI state that should not live in chart or model state:
- `overlayState`: current overlay tab
- `dragging`: transient UI drag state used by scrollbar and snap-grid interactions

View services should mutate `EditorViewState` rather than adding UI-only fields to `EditorModel`.

### `EditorController` — Load/Save/Export
Orchestrates chart loading via `ChartSelector`, saves to `.sph` through `ChartEncoder`, and handles export formats (`.osu`, NanoChart). Delegates NanoChart and BMS-specific exports to dedicated modules in `exports/`.

The load/save boundary is tested with fakes for chart selection, note skin loading, resource lookup, file writes, and library recomputation. Resource path ordering is centralized in `getResourcePaths()`. Editor-owned file writes go through `fs.IFilesystem` instead of direct `love.filesystem` calls.

Modifier application on load is driven by an injected predicate so `EditorController` does not read keyboard state directly. Dropped audio imports are delegated to `EditorDropImport`, which owns extension filtering and writes imported files through `fs.IFilesystem`.

`EditorController` takes a dependency table rather than a long positional constructor. Keep new controller collaborators in that table to avoid argument-order bugs.

`exports/SphChartSaver` owns default `.sph` save behavior and library recomputation. `exports/OsuChartExporter` owns `.osu` export file generation. Both write through `fs.IFilesystem` and have focused tests for write failures.

`exports/NanoChartExporter` owns `.nanochart`, compressed `.nanochart`, and SPH preview file generation. It reads notes from the current `chart.Chart` model after `EditorModel:save()` and writes through `fs.IFilesystem`; do not revive legacy `editorModel.noteChart` usage.

### `NoteChartLoader` — Edit Chart Conversion
Converts the persisted `chart.Chart` into editable `chartedit.Layer` and `chartedit.Notes` data, and writes edited data back into the current chart on save.

`NoteChartLoader` receives a narrow `NoteChartLoaderContext` from `EditorServices` instead of reading the whole `EditorModel`. The context supplies the current chart, layer, and notes lazily so load-time and save-time state changes stay owned by `EditorModel`.

### `VisualEngine` — Note Rendering And Selection
Maintains the pool of visible `EditorNote` wrappers. Each frame it iterates linked notes in the visible time range, creates or reuses note objects, and tracks selection state. Uses `EditorNoteFactory` to produce the correct note subclass.

`VisualEngine` receives `VisualEngineContext` from `EditorServices` for session time, editor settings, visual point, visual, notes, and visible iteration range. Phase 1 keeps a transitional `getEditorModel()` entry only so existing `EditorNote` subclasses can continue receiving `note.editorModel`; do not use that entry for new `VisualEngine` behavior.

Selection state is keyed by the note's current `startNote`. Drag operations that clone notes must update selection keys to avoid stale selected notes after visual refresh.

### `EditorNoteService` — Note Manipulation
Facade for note manipulation commands and composition root for focused note services. Code should require `rizu.editor.EditorNoteService` directly.

`EditorNoteCreateService` owns editor-note construction and add-note tool behavior. It creates the correct editor note class through `EditorNoteFactory`, initializes editor/visual links, selects newly-created notes, and hands them to `EditorNoteDragService` for immediate drag placement. Test setup and service code that need a raw editor note should call `createService:newNote(...)` directly; `EditorNoteService` only exposes the user-facing `addNote(...)` command. It receives `EditorNoteCreateServiceContext`; `getEditorModel()` is a temporary bridge only for initializing existing editor-note wrappers.

`EditorNoteColumnService` owns editor column lookup for note creation and dragging. Tests may set `columnService.columnOver` to force a deterministic hovered column; runtime lookups derive the column from the mouse position and active note skin. It receives `EditorNoteColumnServiceContext`; `setEditorModel()` is a compatibility adapter until note-service composition moves fully to contexts.

`EditorClipboardService` owns copy, cut, and paste behavior. It keeps copied editor notes, chooses the earliest copied point as the paste origin, and records cut/paste undo boundaries through `EditorChanges`. It receives `EditorClipboardServiceContext`; `setEditorModel()` is a compatibility adapter until note-service composition moves fully to contexts.

`EditorNoteDragService` owns note drag lifecycle state and behavior: grabbing existing or newly-created notes, updating unlocked-snap drags, preserving column deltas, dropping notes back into the chart, and restoring selected-note keys. It receives `EditorNoteDragServiceContext`; `setEditorModel()` is a compatibility adapter until note-service composition moves fully to contexts.

`EditorNoteCommandService` owns command-level note mutations: direct note insertion/removal, delete selected, remove one note with undo boundary, change selected note type, and flip selected notes. It wraps `EditorNoteOps` and owns undo/redo boundaries around those commands. New code should call it directly for mutation setup instead of adding private `EditorNoteService` wrappers. It receives `EditorNoteCommandServiceContext`; `setEditorModel()` is a compatibility adapter until the remaining note services move to contexts.

`EditorNoteOps` receives `EditorNoteOpsContext` for note storage, undo/redo recording, layer lookup, and visual lookup. It should not receive an `EditorModel` back-reference; command services may still build the ops context from their current editor-model bridge until those services are split.

`EditorNoteService` is a small UI-facing facade and service composition root. It should not expose low-level `EditorNoteOps` or raw note construction helpers, and it should not mirror collaborator state. Use `getGrabbedNotes()` and `getCopiedNotes()` when UI code needs transient drag or clipboard state.

Note services should receive explicit dependencies from `EditorNoteService` instead of keeping a service-root back-reference. `EditorNoteService:setEditorModel(editorModel)` attaches the model to each service after `EditorModel` has been constructed.

All mutations are recorded through `EditorChanges` for undo/redo support.

Editor tests should use `EditorTestFactory` note helpers for common setup:
`createNote()` for a raw editor note, `addNote()` for chart insertion, `addCommittedNote()` when undo history needs an initial boundary, and `addSelectedNote()` / `addCommittedSelectedNote()` for selected-note command setup. Spell out lower-level `commandService:addNotes(...)` calls only when the test is explicitly covering duplicate insertion, multi-note setup, or low-level note ops.

`EditorTestFactory.createNoteChartLoaderContext(editorModel)`, `createEditorChangesContext(editorModel)`, `createScrollerContext(editorModel)`, `createIntervalManagerContext(editorModel)`, and `createMetronomeContext(editorModel)` mirror the runtime context shapes for lightweight editor-model fakes. Prefer them over rebuilding callback tables in each test.

### `IntervalManager` — Timing Vertex Manipulation
Split, merge, grab, and drop timing vertices on the interval timeline. Delegates to the `ncdk` layer system for the actual vertex data.

`IntervalManager` receives a narrow `IntervalManagerContext` from `EditorServices` instead of reading the whole `EditorModel`. The context reads layer and notes lazily because the manager is attached before chart data is loaded.

Shrinking an interval can remove chartedit points and the visual points/notes anchored to them. `IntervalManager` captures those removed points through `IntervalUpdateSnapshot` before applying the timing mutation so undo/redo can restore or remove both points and notes consistently.

### `Scroller` — Timeline Navigation
Scroll by seconds or snap grid units. Respects vertex boundaries and the current snap resolution.

`Scroller` receives a narrow `ScrollerContext` from `EditorServices` instead of reading the whole `EditorModel`. Cursor writes go through `EditorModel:setSessionPoint()` so timeline state updates have one owner.

### `GraphsGenerator` — Scrollbar Visualization
Generates a note density graph and a vertex graph for the scrollbar UI.

`GraphsGenerator` is argument-driven and should not receive an `EditorModel` back-reference. `EditorModel:genGraphs()` supplies the current chart, layer, and timeline range.

### `EditorChanges` — Undo/Redo
Wraps the generic `Changes` system with method-call commands. Records add/remove note operations with corresponding redo and undo pairs.

`EditorChanges` receives a narrow `EditorChangesContext` with `resetVisual()` instead of reading the whole `EditorModel`. Undo and redo call that reset after replaying a change group so visual note caches and selections are rebuilt by the visual layer.

### `TimeManager` — Playback Timer
Extends `rizu.engine.time.LocalTimer`. Controls play/pause and current playback position.

### `Metronome` — Click Track
Provides a metronome click synced to the current timing data.

`Metronome` receives a narrow `MetronomeContext` from `EditorServices` instead of reading the whole `EditorModel`. It uses the context for current time, current point, next snap lookup, and point interpolation.

Loads its click sample through `fs.IFilesystem` so editor model tests do not depend on `love.filesystem`.

### `NcbtContext` — Tempo And Offset Detection
Runs the NCBT algorithm on the audio waveform to detect tempo and offset. Results can be applied to the chart's interval data.

`NcbtContext` is argument-driven: detection receives sound data, and application receives the target chartedit layer. It should not receive an `EditorModel` back-reference.

### `BmsToolsContext` — BMS State Container
Holds BMS-specific editing state (`offset`, `tempo`, `beat_offset`) and provides `resetOffsetTempo()` to apply those values to the chart's layer vertices. Separated from `EditorModel` to isolate BMS-specific concerns.

`BmsToolsContext` is argument-driven for layer operations. It may store BMS-specific values, but chart mutation should continue to receive the target layer explicitly rather than reading it from `EditorModel`.

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
- Interval timing operations, including split/merge/update, destructive shrink snapshots, note restoration, vertex drag undo/redo, and the `IntervalManagerContext` boundary used by `IntervalManager` and `IntervalUpdateSnapshot`.
- Visual selection refresh, scroller/cursor interaction, editor model load/update lifecycle, and note chart load/save roundtrips. `VisualEngine` uses `VisualEngineContext`, `NoteChartLoader` uses `NoteChartLoaderContext`, `EditorChanges` uses `EditorChangesContext`, `Scroller` uses `ScrollerContext`, `Metronome` uses `MetronomeContext`, and `GraphsGenerator`, `NcbtContext`, and `BmsToolsContext` remain argument-driven without `EditorModel` back-references.
- `EditorController` load/save wiring for note skin, resources, file writes, and library recomputation.
- Resource-load sequencing and lifecycle state ownership through `EditorResourceLoadService` and `EditorRuntimeState`.
- Editor view command, overlay action, and snap-grid scroll behavior through focused services.
- Editor screen enter/exit lifecycle through `EditorScreenLoadService`.
- Editor view service ownership through `EditorViewServices`.
- Editor screen update/draw/receive sequencing through `EditorScreenFrameService`.

Remaining higher-risk areas:
- Editor note classes and note-editing services still carry broad editor-model access and should be split only behind behavior tests. `VisualEngineContext.getEditorModel()` exists only as a temporary bridge for those note classes.
- Graph generation with real charts/audio and waveform/audio resource failure modes beyond service sequencing.
- UI view integration under `ui/views/EditorView/`.
- BMS-specific exporters, intentionally deferred until parser rewrite work.
