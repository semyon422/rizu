# Chart Selection (`rizu.select`)

## Goal
The selection system provides a responsive and intuitive interface for browsing the music library. It manages the hierarchical navigation between song collections, individual files, and playable variations, ensuring the UI stays synchronized with the underlying database.

## User Experience
The player interacts with two main lists: the **Primary List** (the main navigation) and the **Secondary List** (the detail view).
- **Navigation**: Choosing an item in the Primary List (e.g., a Song) automatically updates the Secondary List to show its related content (e.g., all available playable variations).
- **Smooth Browsing**: Scrolling through thousands of items is instantaneous. The system only loads the heavy metadata for items currently visible on the screen.
- **Search & Filter**: Any changes to search queries, sorting, or filters trigger a background library query. The UI maintains the current selection by ID even as the list content changes.
- **Instant Preview**: Selecting a playable variation immediately prepares the game settings (modifiers, rates) and triggers the audio/visual preview system.

## Architecture Decisions (ADR)

### ADR: Two-Level Selection Model
- **Context**: The library has a 5-level deep hierarchy, but presenting all 5 levels simultaneously would overwhelm the player.
- **Decision**: We use a generalized two-level "Drill-down" model. The system maps any two levels of the hierarchy (configured via `primary_mode` and `secondary_mode` in `settings.select`) to a Primary and Secondary view.
- **Consequence**: This flexibility allows the UI to support different navigation styles (e.g., browsing by Set vs. browsing by Metadata) without rewriting the core logic.

### ADR: Off-Thread Retrieval
- **Context**: Performing SQL queries and calculating aggregated metrics for 50,000+ items on the main thread causes significant frame drops.
- **Decision**: All database-intensive operations (queries, drill-downs, score fetching) are offloaded to the `Library.Worker` thread.
- **Consequence**: The UI loop remains unblocked, maintaining 60fps during heavy library refreshes. State updates are coordinated via asynchronous callbacks.

## Implementation Details

### Selection Levels
The system tracks selection across all 5 granularity levels defined in `rizu/library/spec.md`:
1. `chartfile_sets`
2. `chartfiles`
3. `chartmetas`
4. `chartdiffs`
5. `chartplays`

The `SelectionState` container maintains the current `index` and `id` for each level to support selection restoration.

### Components
- **ChartSelector**: The central orchestrator. It manages debounced refreshes, restoration of selection based on IDs after list updates, and orchestration of asynchronous tasks.
- **ListStore**: A reactive proxy for list data (`rizu.select.stores.ListStore`). It utilizes the unified FFI indexing and on-demand enrichment specified in the library module.
- **SelectionState**: A level-based state container tracking the current focus for each hierarchy level.

### Update Lifecycle
1. **Full Refresh**: Triggered by changes in filters, search, or sorting. `ChartSelector:updatePrimaryItems()` calls the library query engine asynchronously.
2. **Level Propagation**: Triggered when the primary selection changes. `ChartSelector:pullLevel(2)` is called to fetch related child items in the worker thread.
3. **Restoration**: After any list update, the system uses mode-aware ID-to-Index maps provided by the query result to re-focus the previously selected item. `chartmetas` and `chartdiffs` restoration uses `chartfile_id` plus the logical ID so duplicate files for the same logical chart do not collapse to the first or last duplicate.

## Synchronization
- **Selected Chart**: The item at the finest active level (typically Level 2) is considered the "Selected Chart."
- **Observables**: UI components bind through `onChanged(observer)` methods for item, selection, and scroll updates. Classes keep the underlying observable in an `observable` field.

### Scores and ReplayBase
`ScoreSelector` owns score list loading and score selection for the current chartview. Score loading is scoped by `settings.select.secondary_mode`:

- `chartfile_sets`, `chartfiles`, `chartmetas`: load scores for the selected `chartmeta` when `hash` and `index` are available.
- `chartdiffs`, `chartplays`: load exact scores for the selected `chartdiff` when a real `chartdiff_id` and complete chartdiff key are available.

Score visibility follows the selected chartview, not the highlighted score row. In coarse modes, the score list shows all plays for the selected song identity (`hash` + `index`) across its playable variations. In `chartdiffs` and `chartplays` modes, the score list shows only plays matching the selected playable variation (`hash`, `index`, `modifiers`, `rate`, and `mode`). `chartplays` mode still shows the exact variation's score list rather than reducing the list to only the selected play; the selected play is restored by `chartplay_id`.

Partial cache states may produce provisional chartviews without a playable variation. Score loading must clear the score list instead of requesting exact chartdiff scores when the selected chartview has no `chartdiff_id`, incomplete `hash` / `index`, or incomplete chartdiff key fields.

Score loads are generation-guarded. Every new chart selection increments the score loading generation; delayed online throttle work and late provider results must be ignored if a newer generation has started. This keeps scores, `SelectionState.scoreId`, and `ScoreSelector.chartplay` aligned with the current chartview.

Online score loading uses an immediate-plus-trailing throttle. The first selected chart after an idle period requests scores immediately. Further chart changes during the throttle window only replace the pending request, and when the window ends the latest pending chart is requested. This keeps online scores responsive without sending a request for every intermediate chart while the player scrolls quickly.

`SelectionReplayBaseApplier` owns the selection-driven mutation of the current `ReplayBase`. `ScoreSelector:updateReplayBase(chartview)` is a compatibility facade that delegates to the applier. The current contract is:

| Secondary mode | ReplayBase update |
| :--- | :--- |
| `chartfile_sets` / `chartfiles` / `chartmetas` | Do not mutate `ReplayBase`; player-selected gameplay settings remain active. |
| `chartdiffs` | Copy chartdiff key fields: `modifiers`, `rate`, and `mode`. |
| `chartplays` | Copy chartdiff key fields plus play-specific fields: `nearest`, `tap_only`, `timings`, `subtimings`, `healths`, `columns_order`, `custom`, `const`, and `rate_type`. |

Manual modifier changes are handled separately by `ModifierCoordinator:update()`, which applies modifier metadata without re-importing selection data and then syncs the current `ReplayBase` to multiplayer.

`ModifierCoordinator` keeps selection-driven and manual modifier flows separate:

- `applySelectionModifierMeta()` is used after chart selection changes. It may import selection fields into the local `ReplayBase` through `SelectionReplayBaseApplier`, then recalculates local modifier metadata and preview rate. It does not sync multiplayer by itself.
- `applyManualModifierMeta()` is used after player-edited modifiers have already changed the local `ReplayBase`. It recalculates local modifier metadata without importing selection fields again.
- `syncManualReplayBaseToMultiplayer()` is called only for manual modifier changes detected by `ModifierSelectModel:isChanged()`. Multiplayer room chart identity comes from `ChartSelector:findChartmeta(hash, index)` and room state, not from selection-driven modifier application.

### TaskRunner Overrides
`rizu.select.tasks.TaskRunner` serializes asynchronous selection work so rapid UI input does not run every obsolete intermediate refresh. It intentionally keeps only one pending task while another task is running.

- A running task is never interrupted.
- Use `TaskRunner.priority.high` for primary refresh, find-chart, and primary-selection work.
- Use `TaskRunner.priority.low` for secondary-selection follow-up work.
- Internally, lower numeric `level` means higher priority.
- If no task is running, the pushed task starts immediately.
- If a task is already running and no pending task exists, the pushed task becomes pending.
- If a pending task exists, a new task replaces it only when the new task has higher or equal priority (`new_level <= pending_level`).
- When the running task finishes, the latest accepted pending task runs next.

This means repeated scroll or refresh input collapses to the most recent relevant task, while coarser selection refreshes can override lower-priority detail work.

### Event Types
Select module event payloads are documented as EmmyLua aliases in `rizu.select.events`. Classes expose typed `onChanged(observer)`, `offChanged(observer)`, and `emitChanged(event)` wrapper methods around their `observable` field. `onChanged` accepts either an observer object or a plain `fun(event)` callback with the concrete event union for that class.

All select events must include a `type` field. Event type names should describe the domain event, not only the payload shape; prefer names such as `score_items_changed`, `list_item_loaded`, or `collection_tree_changed` over generic names such as `items`, `count`, or `tree`. Prefer narrowing event unions with `if event.type == ...` checks and only add explicit casts when LuaLS cannot infer the concrete payload. Prefer `emitChanged` over calling raw `observable:send`, so LuaLS can check the event payload shape.

### Filesystem and OS Integration
`SelectionActions` delegates opening local chart and location directories to `LocationDirectoryOpener`. This keeps selected-location lookup in the action layer while isolating `love.filesystem` source-path resolution and `love.system.openURL` behind an injected service.

### Partial Cache Selection
Selection may point at provisional library rows while caching is still running. A provisional chartview remains a valid list item and can be kept in `SelectionState`, but it is not a playable chart until it has a non-zero `chartmeta_id`, `hash`, `index`, `inputmode`, and `location_path`.

Playable-only effects must be guarded by `ChartSelector:isPlayableChartview(chartview)`. This includes preview activation, audio/background lookup, chart loading, modifier metadata application, and selection-driven `ReplayBase` updates. When selection lands on a provisional row, the preview audio should be cleared and modifier metadata should not be recalculated from incomplete chart data.

### Multiplayer Chart Lookup
`ChartSelector:findChartmeta(hash, index)` is used when a multiplayer room tells the client which chartmeta is required. The lookup intentionally targets `chartmetas` only: it answers whether the client has the song identity (`hash` + `index`). Gameplay variation details such as modifiers, rate, play-specific timing, and other `ReplayBase` fields come from multiplayer room state rather than from this local lookup.

## Future Work and Open Questions

### User Experience
- **Single-list layouts**: The selection model is technically two lists, but some `primary_mode` / `secondary_mode` combinations always produce a secondary list with one logical item. Those modes should probably render as a single-list UI.
- **Incremental cache refreshes**: The lists should update while charts are still being cached, so the player can immediately play anything that has already been processed. This needs design work because rebuilding large lists can take seconds for very large libraries.
- **Collections**: Current collections are folder-like path prefixes used for filtering. Keep that behavior, but consider renaming it to make room for real user-defined collections. Collections may also need separate scopes for sets, metas, diffs, and plays.

### Selection, Scores, and Replay State
- **ReplayBase ownership**: Reconsider whether selection should automatically mutate the global `ReplayBase`. It may be safer to work with a copy until the player explicitly confirms gameplay settings.

### Boundaries and Dependencies
- **Event wiring**: Centralize event-based system coupling if possible. `SelectionCoordinator` already handles some of this, but there may be additional event wiring elsewhere.
- **UI-only effects**: Move UI concerns out of selection logic, including `self.windowModel:setVsyncOnSelect(true)`.
- **Configuration IO**: Move config persistence out of the select module. Calls such as `self.configModel:write()` make selection responsible for IO that belongs at a higher layer.
- **Dependency inversion**: Consider introducing interfaces around services used by `rizu.select` so the module depends on selection-domain contracts instead of concrete application models.

### Types and Naming
- **Location DTO split**: Split `rizu.library.Location` into two shapes: the full runtime entity and a narrower insert-data record used by repositories. Look for similar patterns elsewhere before applying this broadly.
- **Untyped data params**: Replace broad annotations such as `---@param data table` with specific DTO or record types.
- **Integer annotations**: Use `integer` for indexes and IDs, for example `level`, `index`, and optional `id` parameters that are currently annotated as `number`.
- **Score naming**: Rename `scoreId`-style identifiers toward `play` / `chartplay` terminology to match the library hierarchy.
- **FilterModel annotations**: Add missing annotations in `FilterModel` and related model classes.

### Filters and Task Infrastructure
- **Filter editing**: Reconsider how custom filters merge with defaults. A dedicated in-game filter editor may be better than manual config editing; if so, persist the complete filter set instead of merging custom filters into defaults at runtime.
- **ChartMetadataService shape**: Consider splitting `ChartMetadataService` or renaming it if it currently owns multiple responsibilities.
- **Formatting cleanup**: Repository-wide formatting cleanup is still needed, but it is broader than the select module and should be handled separately.
