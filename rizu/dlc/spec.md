# DLC System (`rizu.dlc`)

## Goal
The DLC system enables players to expand their music library directly from within the game. It provides a modular framework for discovering, downloading, and installing content from external platforms like osu! and Etterna without requiring manual file management.

## User Experience
Players access the **DLC Screen** from the sidebar to browse and search for new content.
- **Discovery**: A unified search interface allows players to select a specific platform (provider) and search for content within it.
- **Filtering**: Results can be narrowed down using platform-specific criteria, such as key counts for Etterna or difficulty ratings for osu!.
- **Previewing**: For supported content types (currently only osu! beatmapsets), players can see thumbnails and listen to 10-second audio previews to evaluate a chart before downloading.
- **Background Downloads**: Clicking "Download" triggers a background process. Players can continue browsing or playing other songs while a progress bar shows real-time speed and completion status.
- **Auto-Installation**: Once a download completes, the content is automatically extracted and indexed. The library is refreshed, and the new charts appear immediately in the song selection screen.

## Architecture Decisions (ADR)

### ADR: Main-Thread Network Service
- **Context**: Network transport has moved to `rizu.net.NetworkService`, which owns the shared cosocket scheduler, async DNS, TLS policy, and HTTP streaming helpers.
- **Decision**: `DlcManager` requires a `NetworkService` and creates its `DlcWorker` in the main thread. `DlcWorker` receives request and download functions from the manager instead of using `ThreadRemote`.
- **Consequence**: DLC search and download share the same scheduler as online WebSocket traffic. Large filesystem and archive work remains isolated behind `DlcInstaller`, which can later gain an async implementation without reintroducing a network worker.

### ADR: Injectable Provider Requests
- **Context**: DLC providers need HTTP search APIs, but transport policy is moving toward `rizu.net.NetworkService`.
- **Decision**: `DlcWorker` requires injected request and download functions. Search-capable providers require the request function from `DlcWorker` instead of calling `web.http.util.request` directly. `DlcWorker:download` similarly uses the injected download function with progress callbacks.
- **Consequence**: Search and download code stays testable with fake requests. `DlcManager` wires these functions to `NetworkService:request` / `NetworkService:download`.

### ADR: Third-Party Mirrors for osu!
- **Context**: The official osu! beatmap API requires OAuth authentication for downloads, which would require players to log in to download charts.
- **Decision**: We route osu! downloads through public mirrors (e.g., BeatConnect, Mino).
- **Consequence**: Players can download content without authentication, though we are dependent on the availability and uptime of these third-party services.

## Implementation Details

### Download Types
The system handles three primary content types, which determine the extraction destination:
- **`pack`**: Large archives containing multiple song folders (e.g., Etterna packs). Extracted to `userdata/charts/packs/`.
- **`set`**: Archives for a single song grouping (e.g., osu! beatmapsets). Extracted to `userdata/charts/downloads/`.
- **`file`**: Individual chart files. Downloaded to a specific destination folder or `userdata/charts/downloads/`.

### Archive Extraction
The `DlcExtractor` utility handles `.zip` and `.osz` formats.
- **Flattening**: Many archives (like Etterna packs) wrap their contents in a redundant top-level folder. The extractor automatically flattens these structures during extraction to ensure the `dir` field in the library remains clean (e.g., `PackName/Song/` becomes `Song/`).
- **Installer boundary**: `DlcWorker` owns provider lookup, transport, filename selection, and progress updates. `DlcInstaller` owns filesystem writes and archive extraction.
- **Async install**: The default worker installer is `AsyncDlcInstaller`, which runs `DlcInstaller:install()` through `thread.async`. Downloading stays on the shared cosocket scheduler while blocking filesystem writes and archive extraction run off the main thread.

### Provider Reference (Technical)

#### 1. osu! Beatmapsets (Type: `set`)
- **Download URLs**: 
  - `https://beatconnect.io/b/BEATMAP_SET_ID`
  - `https://catboy.best/d/BEATMAP_SET_ID`
- **Search APIs**:
  - **Mino (JSON)**: `https://catboy.best/api/v2/search`
  - **osu!direct (Text)**: 
    - Akatsuki: `https://osu.ppy.sb/web/osu-search.php?r=4&m=3&p=0&q=`
    - Ripple: `https://ripple.moe/web/osu-search.php?r=4&m=3&p=0&q=`
  - **Official (Unauthorized)**: `https://osu.ppy.sh/beatmapsets/search`
- **Assets**:
  - Thumbnails: 
    - 400x140: `https://assets.ppy.sh/beatmaps/{id}/covers/card.jpg`
    - 150x150: `https://assets.ppy.sh/beatmaps/{id}/covers/list.jpg`
    - 900x250: `https://assets.ppy.sh/beatmaps/{id}/covers/cover.jpg`
  - Audio Preview (10s): `https://b.ppy.sh/preview/{id}.mp3`

#### 2. osu! Individual Charts (Type: `file`)
- **Download**: `https://osu.ppy.sh/osu/BEATMAP_ID` (Direct `.osu` file download, no auth required).

#### 3. Etterna Packs (Type: `pack`)
- **Download**: `https://downloads.etternaonline.com/ranked/PackName.zip`
- **Search**: `https://api.etternaonline.com/api/packs?page=1&limit=36&sort=name&filter[search]=SEARCH_QUERY`
- **Filters**: Supports sorting by popularity/difficulty and filtering by key count (`4k`-`10k`) or tags (stamina, technical, etc.).
