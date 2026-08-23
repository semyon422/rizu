# Flexible Library Querying (`rizu.library`)

## Goal
The library system is designed to provide a fast, flexible, and deeply hierarchical way to navigate tens of thousands of song charts. It replaces rigid grouping settings with a dynamic system that allows players to organize their collection by sets, individual files, or specific playable variations on the fly.

## User Experience
- **Dynamic Hierarchy**: Players can choose how the main list and sub-lists are organized independently (e.g., "Group by Set" for the primary list and "Show Playable Variations" for the secondary list).
- **Deep Drill-down**: The interface supports 5 levels of granularity, from coarsest (Chart Sets) to finest (Individual Plays/Scores).
- **Aggregated Sorting**: When sorting a grouped list (like Sets) by an attribute like difficulty, the system uses the "maximum" value within that group (e.g., the set is sorted by its hardest variation).
- **Instant Scrolling**: Even with 50,000+ charts, the song list remains responsive thanks to lazy loading and zero-copy memory management.
- **External Imports**: Players can add local folders from other games as library locations, download packs through DLC, or drop supported files into the client. The library normalizes those sources into the same location/set/file/meta/diff hierarchy.

## Data Entities
The library is structured around a 5-level hierarchy, where each level represents a more specific view of the content:

- **Location** (`locations`): The base storage root for charts. It represents a physical directory on the user's disk.
  - **Internal**: Direct access to the game's `userdata/charts` folder.
  - **External**: Arbitrary folders (e.g., an existing osu! installation) that are **mounted** into the game's virtual filesystem at a specific prefix.
  - The `rizu.library.Locations` service resolves absolute "real" paths for assets by combining the location's base path with the chart's relative directory.
- **Chartfile Set** (`chartfile_sets`): The primary storage unit. It tracks the `dir` (relative path from Location) and `location_id`. Higher-level organizational folders (like Etterna Packs or the osu! `Songs` folder) are not separate entities; they are simply represented as part of the `dir` string.
  - **Folder**: Used for "Related" charts that share assets (e.g., a specific folder for an osu! beatmapset or an Etterna song). Sets directly under the location root have a `NULL` `dir`; rich chart paths must still include the set name and chartfile name.
  - **Single File**: Used for "Unrelated" self-contained charts (e.g., `.ojn`, `.mid`).
- **Chartfile** (`chartfiles`): A single physical file containing chart data (e.g., `.osu`, `.sm`, `.bms`). It is identified by a content `hash` and linked to a set via `set_id`.
- **Chartmeta** (`chartmetas`): The logical identity of a song. It is identified by a `ChartmetaKey` (content `hash` + `index` within the file). It contains high-level metadata like `title`, `artist`, `audio_path`, and `preview_time`.
- **Chartdiff** (`chartdiffs`): A specific playable variation. It is identified by a `ChartdiffKey` (MetaKey + `mode` + `rate` + `modifiers`). It stores difficulty metrics (`msd`, `osu`, `enps`) and `notes_count`.
- **Chartplay** (`chartplays`): A record of a performance attempt. It tracks `accuracy`, `grade`, `judges` (hit counts), and a `replay_hash`.

## Architecture Decisions (ADR)

### ADR: Metadata-Driven IIDX Locations
- **Context**: beatmania IIDX game data stores song metadata globally in `info/*/music_data.bin` and chart payloads in `sound/*.ifs`, so recursively treating every file as a normal chart folder is both slow and semantically wrong.
- **Decision**: Locations that contain `info/*/music_data.bin` and `sound/` are auto-detected as IIDX data roots during cache updates. They use a metadata-driven scanner that imports only metadata-listed `.ifs` archives or extracted song folders present on disk.
- **Consequence**: Users can add an IIDX `contents/data` folder as a regular location while the library avoids regular recursive scanning for that root. Each `.ifs` archive or extracted song folder is stored as a chartfile set, and its `.1` payload is stored as the chartfile and hash identity. IIDX gameplay loads `.s3p`/`.2dx` keysounds from the same set; preview audio and BGA assets are resolved through the same resource paths.

### ADR: Unified FFI Indexing
- **Context**: Transferring thousands of rich Lua tables between the database thread and the UI thread causes massive garbage collection pressure and "stuttering."
- **Decision**: We use a custom C-struct (`chartview_struct`) containing essential IDs and flags (lamp status, etc.). Query results are returned as a packed buffer of these structs along with a set of **ID-to-Index maps**.
- **Consequence**: Memory usage is significantly reduced, and the UI can restore selection instantly after a refresh using the maps. All selection levels (Primary, Secondary) use this unified indexing.

### ADR: Stateless Query Engine
- **Context**: The `Library.Worker` thread needs to handle multiple simultaneous requests without complex state synchronization.
- **Decision**: The `ChartviewsRepo` is completely stateless. Every query returns a self-contained `QueryResult` object containing the result buffer and all necessary lookup maps.
- **Consequence**: High performance and no risk of race conditions when the user rapidly changes filters or search queries.

## Selection Logic

### Granularity Levels
The library utilizes a 5-level hierarchy to manage the transition from physical files to logical gameplay entities. While typically 1:N, the relationship between files and songs can vary by format:

1.  **`chartfile_sets`**: Groups by storage unit (Song Folder/Archive). Coarsest level (e.g., a single osu! Beatmapset folder).
2.  **`chartfiles`**: Groups by physical file. Distinguishes between different files even if they share the same content.
3.  **`chartmetas`**: Groups by logical song (Content `hash` + `index`). Expands multi-song archives (e.g., O2Jam `.ojn` files).
4.  **`chartdiffs`**: Groups by playable variation. Unique combination of a song (`chartmeta`), `mode`, `rate`, and `modifiers`.
5.  **`chartplays`**: Individual performance records. Finest level, tracking score history.

**Logistics Chain**: `Set` (1:N) `File` (N:M) `Meta` (1:N) `Diff` (1:N) `Play`.
- **N:M** (File to Meta): One file can contain multiple songs (O2Jam), and multiple files can represent the same song (Duplicates).

### Primary List (Main List)
The primary list is always grouped by the `primary_mode`. 
- If `primary_mode = chartfile_sets`, the list shows sets.
- If `primary_mode = chartmetas`, the list shows individual chart metadata groupings.

### Secondary List (Sub-list)
The secondary list's content is dynamically determined by comparing the `primary_mode` and `secondary_mode` using these rules:
- **Scope (Filtering)**: The items are filtered by the ID(s) of the **coarser** of the two modes.
- **Granularity (Grouping)**: The items are grouped by the **finer** of the two modes.
- **Ordering**: Secondary-list queries use a fixed contextual order instead of the primary list's configured sort order. For chart metadata and playable variations, items are ordered by input-mode specificity, actual chartdiff input mode, original input mode, difficulty, variation name, then stable chart IDs. When the secondary mode reaches `chartplays`, items are ordered by `chartplay_id`.

This fixed secondary order is intentional. The primary list is the player's browsing and sorting surface, while the secondary list provides local context for the selected primary item. Reusing the primary sort there can make sibling charts or variations jump into an order that is useful globally but confusing inside a single set, song, or variation group.

### Aggregation Rules
When grouping at a coarser level, data for the finer levels is picked using these defaults:
- **Default Chartmeta**: The one with the lowest `id`.
- **Default Chartdiff**: The "Base" playable variation (rate = 1.0, no modifiers).
- **Default Chartplay**: The latest play (highest `created_at` or `id`).

## Implementation Details

### Data Enrichment (Lazy Loading)
To keep the memory footprint minimal, rich metadata (titles, artists, paths) is fetched on-demand:
1. The UI/Store holds only the slim FFI index (`chartview_struct`).
2. `getChartview(struct)` is called only for items currently in the viewport.
3. `rizu.library.Locations` provides a high-speed path resolution service using an in-memory cache to avoid redundant SQL queries.

### Module Boundaries
`rizu.library` owns persistent chart storage, cache updates, path resolution, collection trees, and query semantics. Its public surface should answer questions such as "which chart rows exist?", "how are they grouped?", "where is this asset on disk?", and "which score rows match this chart key?"

`rizu.select` owns UI state and interaction on top of those answers: active primary/secondary modes, selected indexes, scroll restoration, preview activation, score-list visibility, `ReplayBase` synchronization, and OS actions such as opening a selected folder. Select code may rely on library query invariants, but library code should not depend on select state.

### Locations, Mounts, and Imports
Locations are the boundary between user-visible folders and library-relative chart paths.

- The default internal location is `userdata/charts` with direct relative access.
- Relative locations are read directly from their stored `path`.
- External absolute locations are mounted through the filesystem under `mounted_charts/<location_id>`; chart queries continue to store paths relative to the location, not relative to the mount point.
- `Locations:enrichChartview` attaches `location_prefix`, `location_dir`, `location_path`, `real_dir`, and `real_path` to rich chartviews for media lookup, chart loading, and OS actions.

The mounts view is the player/developer surface for this location state. Its `locations` tab can show per-location cache counts, create locations, rename or repath non-internal locations, include or hide locations in the collection tree via `settings.select.locations_in_collections`, open either the selected chart directory or the location root through select actions, update cache for the selected chart folder, update cache for a whole location, stop an active location update, delete one location's chart cache, and delete non-internal locations.

The same view also has a `database` tab for broader maintenance. It shows aggregate metadata/diff/play counts, refreshes those status counters, starts missing or incomplete chartdiff computation, optionally computes incomplete diffs using preview data, recomputes chartplay-derived score data, resets individual difficulty-calculation fields, deletes all chart cache rows, deletes all or modified chartdiffs, deletes chartdiffs for the selected chart, resets `chartfiles.hash`, deletes all chartmetas or chartmetas by format, runs a selected-chart difficulty debug calculation, and exposes a database `VACUUM` action. Destructive buttons are generally left-shift guarded in the UI.

DLC and drag-and-drop flows import into the internal location rather than creating a separate storage model. DLC packs are extracted under `userdata/charts/packs`, downloaded beatmapsets under `userdata/charts/downloads`, and single downloaded files into their destination folder. `LibraryDropManager` similarly creates or extracts content under `userdata/charts` and then requests a scoped `computeLocation` update.

Current `.osz` import handling is extraction-based: DLC and drag-and-drop expand `.osz` archives into ordinary chart folders before the library scans them. Direct `.osz` container reading is not part of the library path model yet; if it is added later, it should follow the same container-path rules used by `.ifs`.

Chart-set export converts every chart in the selected physical set to `.osu` and writes one `.osz` under `userdata/export`. The normal mode copies ordinary chart resources into the archive, extracts referenced virtual keysounds from packed formats such as IIDX `.s3p`/`.2dx`, and rewrites exported `.osu` sample references to those extracted archive files. Packed keysound banks are not copied into the `.osz` when their referenced samples have been extracted. The compiled-audio mode renders each chart's backing audio and playable keysounds to one WAV, removes keysound references from the exported chart, and uses that WAV as its audio track. Compilation intentionally produces one audio file per chart because keysound timing can differ between variations in the same set.

### Container Chart Paths
Most chartfiles are ordinary filesystem files, but IIDX `.ifs` archives are represented as container paths. `ChartfileReader` treats any path matching `*.ifs/<internal path>` as an archive read: the `.ifs` prefix is read from the filesystem, then the remaining path is looked up inside the parsed archive.

For metadata-driven IIDX locations:

- The scanned location root is the IIDX `contents/data` directory.
- Song metadata is loaded from standard `info/*/music_data.bin` files and omnimix `info/*/music_omni.bin` files. Omnimix metadata uses the same database layout after decoding its obfuscated 64-byte header. When standard and omnimix databases have the same version, omnimix entries take priority while the standard database fills IDs absent from the overlay.
- Present chart archives and extracted song folders are discovered under `sound/`.
- Each archive, such as `sound/01234.ifs` or `sound/01234-p0.ifs`, is stored as one `chartfile_set` with `dir = "sound"` and `name` equal to the archive filename.
- An extracted directory named `sound/01234` or `sound/01234-p0` is stored identically as a non-file chartfile set. Its chartfile is the flat `01234.1` file directly inside the folder. Archives take priority if both packed and extracted forms exist.
- The playable payload inside an archive is stored as a `chartfile` named `<song_id>/<song_id>.1`, for example `01234/01234.1`; an extracted folder stores `<song_id>.1`.
- Runtime reads combine the location prefix, set directory, set name, and chartfile name into paths such as `mounted_charts/2/sound/01234.ifs/01234/01234.1` or `mounted_charts/2/sound/01234/01234.1`.
- IIDX preview audio, BGA, and keysounds are resolved relative to the same set conventions; chart loading creates an IIDX decode context from the location prefix and chartfile name.

### Partial Cache States
Cache updates move chart data through several valid intermediate states. The rest of the system must treat these as normal data, not as corruption:

1. **Scanned**: `chartfile_sets` and `chartfiles` exist, but `chartfiles.hash` is still `NULL`. Metadata, diffs, plays, and difficulty values may be absent.
2. **Hashed and parsed**: `chartfiles.hash` and `chartmetas` exist. Default `chartdiffs` may still be missing if parsing or difficulty calculation failed or has not run yet.
3. **Default diff computed**: Base `chartdiffs` exist, but modified diffs, score-linked diffs, chartplays, or computed score data may still be missing.
4. **Fully enriched**: Metadata, default and modified diffs, scores, and derived difficulty/score fields are available.

Query behavior should preserve provisional rows where possible. `ChartviewsRepo` uses `LEFT JOIN` for metadata, diffs, and plays in non-`chartplays` modes, so scanned-only files can still appear in `chartfile_sets`, `chartfiles`, `chartmetas`, and `chartdiffs` views with missing logical IDs represented as `0` in the slim FFI index. `chartplays` mode requires actual play rows and may be empty for the same files.

Callers must guard optional data before using rich chart fields. Selection can keep a provisional `chartview` by `chartfile_id`, but preview, score loading, chart loading, replay-base sync, and UI detail panels must handle missing `hash`, `index`, `title`, `chartmeta_id`, `chartdiff_id`, difficulty values, and media paths.

### Query Logic Matrix
| Primary Mode | Secondary Mode | Filter Level | Group Level | User Experience |
| :--- | :--- | :--- | :--- | :--- |
| `chartfile_sets` | `chartmetas` | `set` | `meta` | **Drill-down:** Select a set, see all its charts (base variations). |
| `chartmetas` | `chartfile_sets` | `set` | `meta` | **Context:** Select a chart, see its "siblings" in the same set. |
| `chartmetas` | `chartmetas` | `meta` | `meta` | **Focus:** Select a chart, see only that chart (base variation). |
| `chartmetas` | `chartdiffs` | `meta` | `diff` | **Drill-down:** Select a chart, see all its playable variations/modifiers. |
| `chartdiffs` | `chartmetas` | `meta` | `diff` | **Context:** Select a variation, see all variations of that chart. |
| `chartfile_sets` | `chartdiffs` | `set` | `diff` | **Deep Drill-down:** Select a set, see all variations of all charts in it. |

### Selection Examples
These examples use player-facing modes and intentionally skip `chartfiles`, which mostly exists to preserve physical-file identity for duplicates and format internals.

If `primary_mode = chartfile_sets` and `secondary_mode = chartmetas`, the primary list shows packs, folders, or archives. Selecting an osu! beatmapset folder scopes the secondary list to that set and shows each song identity inside it. For ordinary single-song folders this usually looks like one song; for multi-song formats or duplicate metadata, it can show multiple chartmetas.

If `primary_mode = chartmetas` and `secondary_mode = chartdiffs`, the primary list is song-oriented. Selecting a song scopes the secondary list to that chartmeta and shows playable variations such as base rate, rate variants, converted modes, or modifier-derived diffs.

If `primary_mode = chartfile_sets` and `secondary_mode = chartdiffs`, the primary list stays folder/archive-oriented, but selecting a set shows all playable variations for every chartmeta in that set. This is useful when a pack/folder is the main browsing unit but the player wants to choose a specific variation directly.

If `primary_mode = chartdiffs` and `secondary_mode = chartmetas`, selecting a playable variation still scopes by the containing chartmeta. The secondary list provides local context by showing the other variations of the same song, rather than jumping to unrelated charts.

If `primary_mode = chartmetas` and `secondary_mode = chartplays`, selecting a song scopes the secondary list to score history for that song identity. This can include plays across multiple playable variations when the query groups by chartmeta first; exact score visibility in the select UI is further constrained by `rizu.select` score-loading rules.

## Future Work and Open Questions

### Caching and Performance
- **Incremental cache updates**: Add a mechanism for library lists to update while chart caching is still running. Players should be able to play charts that have already been processed instead of waiting for the whole cache run.
- **Partial cache states**: Review, document, and test behavior while the cache is incomplete. Intermediate states are valid system states, so queries, selection, previews, scoring, and UI refreshes must handle missing hashes, metadata, diffs, scores, or difficulty values without assuming the full pipeline has finished.
- **Pipeline parallelism**: Split caching into stages that can surface partial results. A fast first pass could show discovered files as provisional charts; later passes can parse metadata, refresh list entries, and calculate difficulty.
- **Difficulty calculation**: Benchmark the cache pipeline. Difficulty calculation is likely a bottleneck and may need to run later or across multiple worker threads. Metadata parsing is more likely to be limited by file IO.
- **On-scroll recache checks**: Consider checking whether the currently visible file has changed while scrolling and recache only that file if needed. This must be clearly communicated to the player and tightly scoped. For osu! files, the game could also check the osu! website and offer a local update when a newer version exists.
- **Worker repo lifetime**: Repositories in the worker are currently created on demand. Consider constructing them once in the worker constructor if that reduces overhead without making state harder to reason about.

### Architecture and Boundaries
- **LibraryDropManager**: Review `LibraryDropManager`; it appears legacy and may need a cleaner design.
- **Future `.osz` support**: Consider direct `.osz` reading using the same container-oriented approach as `.ifs`.
- **Export filesystem boundary**: Move `ChartExporter:exportToOsu` behind an `IFilesystem` abstraction so export code does not depend directly on concrete filesystem APIs.
- **Database path ownership**: Make the database path required at `Database:load(path)` and move fallback resolution to a higher level. Add a command-line option for selecting a database path so developers can open a different database without renaming files.
- **Logging**: Add a logging class or interface in `aqua` and use it instead of direct `print` calls. This is a repository-wide concern, not just a library change.
- **DifficultyModel extensibility**: `DifficultyModel` can accept custom difficulty calculators, but that capability is not exposed well. Design a player- or developer-facing way to configure and use custom calculators.

### Types and Coroutines
- **Model typing**: Add stronger annotations for library models where LuaLS currently sees broad or unknown shapes.
