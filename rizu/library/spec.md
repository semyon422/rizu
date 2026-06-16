# Flexible Library Querying (`rizu.library`)

## Goal
The library system is designed to provide a fast, flexible, and deeply hierarchical way to navigate tens of thousands of song charts. It replaces rigid grouping settings with a dynamic system that allows players to organize their collection by sets, individual files, or specific playable variations on the fly.

## User Experience
- **Dynamic Hierarchy**: Players can choose how the main list and sub-lists are organized independently (e.g., "Group by Set" for the primary list and "Show Playable Variations" for the secondary list).
- **Deep Drill-down**: The interface supports 5 levels of granularity, from coarsest (Chart Sets) to finest (Individual Plays/Scores).
- **Aggregated Sorting**: When sorting a grouped list (like Sets) by an attribute like difficulty, the system uses the "maximum" value within that group (e.g., the set is sorted by its hardest variation).
- **Instant Scrolling**: Even with 50,000+ charts, the song list remains responsive thanks to lazy loading and zero-copy memory management.

## Data Entities
The library is structured around a 5-level hierarchy, where each level represents a more specific view of the content:

- **Location** (`locations`): The base storage root for charts. It represents a physical directory on the user's disk.
  - **Internal**: Direct access to the game's `userdata/charts` folder.
  - **External**: Arbitrary folders (e.g., an existing osu! installation) that are **mounted** into the game's virtual filesystem at a specific prefix.
  - The `rizu.library.Locations` service resolves absolute "real" paths for assets by combining the location's base path with the chart's relative directory.
- **Chartfile Set** (`chartfile_sets`): The primary storage unit. It tracks the `dir` (relative path from Location) and `location_id`. Higher-level organizational folders (like Etterna Packs or the osu! `Songs` folder) are not separate entities; they are simply represented as part of the `dir` string.
  - **Folder**: Used for "Related" charts that share assets (e.g., a specific folder for an osu! beatmapset or an Etterna song).
  - **Single File**: Used for "Unrelated" self-contained charts (e.g., `.ojn`, `.mid`).
- **Chartfile** (`chartfiles`): A single physical file containing chart data (e.g., `.osu`, `.sm`, `.bms`). It is identified by a content `hash` and linked to a set via `set_id`.
- **Chartmeta** (`chartmetas`): The logical identity of a song. It is identified by a `ChartmetaKey` (content `hash` + `index` within the file). It contains high-level metadata like `title`, `artist`, `audio_path`, and `preview_time`.
- **Chartdiff** (`chartdiffs`): A specific playable variation. It is identified by a `ChartdiffKey` (MetaKey + `mode` + `rate` + `modifiers`). It stores difficulty metrics (`msd`, `osu`, `enps`) and `notes_count`.
- **Chartplay** (`chartplays`): A record of a performance attempt. It tracks `accuracy`, `grade`, `judges` (hit counts), and a `replay_hash`.

## Architecture Decisions (ADR)

### ADR: Metadata-Driven IIDX Locations
- **Context**: beatmania IIDX game data stores song metadata globally in `info/*/music_data.bin` and chart payloads in `sound/*.ifs`, so recursively treating every file as a normal chart folder is both slow and semantically wrong.
- **Decision**: Locations that contain `info/*/music_data.bin` and `sound/` are auto-detected as IIDX data roots during cache updates. They use a metadata-driven scanner that imports only metadata-listed `.ifs` archives present on disk.
- **Consequence**: Users can add an IIDX `contents/data` folder as a regular location while the library avoids regular recursive scanning for that root. Each `.ifs` archive is stored as a chartfile set, and the internal `<song_id>/<song_id>.1` chart payload is stored as the chartfile and hash identity. IIDX gameplay loads `.s3p` keysounds from the same `.ifs`; preview audio and BGA are left for later passes.

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

### Query Logic Matrix
| Primary Mode | Secondary Mode | Filter Level | Group Level | User Experience |
| :--- | :--- | :--- | :--- | :--- |
| `chartfile_sets` | `chartmetas` | `set` | `meta` | **Drill-down:** Select a set, see all its charts (base variations). |
| `chartmetas` | `chartfile_sets` | `set` | `meta` | **Context:** Select a chart, see its "siblings" in the same set. |
| `chartmetas` | `chartmetas` | `meta` | `meta` | **Focus:** Select a chart, see only that chart (base variation). |
| `chartmetas` | `chartdiffs` | `meta` | `diff` | **Drill-down:** Select a chart, see all its playable variations/modifiers. |
| `chartdiffs` | `chartmetas` | `meta` | `diff` | **Context:** Select a variation, see all variations of that chart. |
| `chartfile_sets` | `chartdiffs` | `set` | `diff` | **Deep Drill-down:** Select a set, see all variations of all charts in it. |
