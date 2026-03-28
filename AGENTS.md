# AGENTS.md

## Project Overview

This project is an open-source rhythm game called "Rizu". It is built using the [LÖVE](https://love2d.org/) framework and is written primarily in Lua. The game is designed to be cross-platform, with support for Windows and Linux.

The project is structured into several key directories:

*   **`rizu/`**: This directory contains the modern, recently rewritten game code. New development and features are primarily focused here.
*   **`sphere/`**: This folder contains older code with an older structure. It is planned to be fully rewritten and integrated into the `rizu/` folder eventually.
*   **`sea/`**: This directory contains code related to the website, server-side logic, and some shared code components.
*   **`aqua/`**: A general-purpose Lua library with various utility modules.
*   **`3rd-deps/`**: Third-party dependencies.
*   **`chartbase/`**: Contains parsers for various rhythm game chart formats (e.g., bms, osu, stepmania).

## Building and Running

The project can be run directly from the source using the LÖVE engine.

**To run the game:**

The game is distributed with LÖVE bundled. Use the provided `game-*` scripts to start it:
-   `game-linux` for Linux
-   `game-macos` for macOS
-   `game-win64.bat` for Windows

**To run tests:**

The project includes a testing framework. Tests can be run from the command line using the following command structure:

```bash
./test [file_pattern] [method_pattern]
```

*   `file_pattern` (optional): A pattern to filter which test files to run (e.g., `rizu/gameplay/GameplayTimings_test.lua`).
*   `method_pattern` (optional): A pattern to filter specific test methods within a file.

For example, to run all tests in `rizu/gameplay/GameplayTimings_test.lua`:

```bash
./test rizu/gameplay/GameplayTimings_test.lua
```

## Development Conventions

The codebase is written in Lua and follows a modular structure. It uses a custom class implementation and a package loader.

The project uses a custom decorator system (`aqua/deco.lua`) for features like profiling and type checking.

The `.editorconfig` file in the root of the repository specifies the coding style for the project. It is recommended to use an editor with EditorConfig support to ensure consistent coding style.

*   **Indentation:** Tabs should be used for indentation. Do not add indentation to empty lines.
*   **Constructors:** Empty `:new()` methods in class definitions should be omitted.
*	**Class Naming & Namespacing:**
	*	**Legacy Style:** Use `prefix.ClassName` (e.g., `sea.UserConnectionsRepo`). Avoid deep nesting like `sea.app.repos.UserConnectionsRepo`.
	*	**Mandate:** Class names (in `@class` annotations and code) CANNOT be derived solely from file paths. You MUST read the file's definition or rely on existing usage in the codebase to determine the correct namespace and class name.
	*	**Modern Style (`rizu.*`):** Follows a hierarchical, directory-based namespacing convention.
		*	**Namespaces:** Use concise lowercase names (e.g., `rizu.library`). Namespaces do not have to match the full directory path; a module-level prefix is preferred (e.g., all classes in `rizu/library/` and its subdirectories should use the `rizu.library` prefix).
		*	**Classes:** Named after their PascalCase filename (e.g., `rizu.library.Library`, `rizu.library.LocationsRepo`).
		*	**Suffixes:** Use semantic suffixes for component roles: `Repo` for database access, `Generator` for data transformation, `Task` for long-running operations, `Manager` for high-level coordination.
		*	**File Alignment:** The filename MUST match the class name (e.g., `rizu.library.LocationsRepo` must be in `rizu/library/repos/LocationsRepo.lua`).
		*	**Interfaces:** Prefixed with `I` (e.g., `rizu.library.ITaskContext`).
		*	**Encapsulation:** Implementations are grouped by feature in subdirectories (e.g., `rizu/library/tasks/`, `rizu/library/generators/`).

*   **Shared Memory:** Use the `web.SharedMemory` class (`aqua/web/nginx/SharedMemory.lua`) to access OpenResty shared dictionaries. Dictionaries must be defined in `nginx_config.lua` under the `shared_dicts` table to be automatically included in the generated `nginx.conf`.
    *   **Cross-Worker Communication:** For communication between different nginx workers/connections, use shared memory queues (e.g., `aqua/icc/SharedMemoryQueue.lua`). These queues should store messages encoded as strings (using `icc.StringBufferPeer`).
*   **Repository Pattern for Shared Memory:** Follow the repository pattern for shared memory access. Create a dedicated repo class (e.g., `sea.UserConnectionsRepo`) that wraps the `ISharedDict` and provides semantic methods. These repos should be initialized in `sea.Repos` using the `SharedMemory` instance passed from `App`.
*   **ICC / Remotes:** ICC stands for **Inter-Context Communication**. It is used for communication between different contexts, such as between the server and client (via websockets) or between different threads (using `ThreadRemote`). Classes ending in `Remote` (e.g., `ServerRemote`) are the primary interfaces for ICC. They typically have a corresponding `Validation` wrapper (e.g., `ServerRemoteValidation`) and require methods to be whitelisted in `sea/app/remotes/whitelist.lua`.
    *   **Field Tooltips:** `IClientRemoteContext` and `IServerRemoteContext` are used as base classes to provide EmmyLua tooltips for common fields (like `user`, `session`, `ip`, `port`). These specific classes should only contain field definitions, not methods.
    *   **Architecture (Proxies & Remotes):**
        *   **`icc.Remote` (The Proxy):** On the caller's side, a `Remote` object acts as a proxy. Indexing it (`remote.path.to.method`) records the access path. Calling it sends an `icc.Message` containing the path and arguments to the peer.
        *   **Validation Wrappers:** To provide type safety and IDE support, `Remote` objects are usually wrapped in classes like `ClientRemoteValidation`. These wrappers mirror the remote API and forward calls to the underlying `Remote` proxy.
        *   **`icc.RemoteHandler` (The Dispatcher):** On the receiver's side, a `RemoteHandler` receives the message. It traverses its own "real" object (e.g., `ServerRemote`) using the path from the message to find the corresponding function.
        *   **Context Injection:** Before calling the function, `RemoteHandler` injects context (like `ip`, `port`, `user`) into the `self` object of the handler. These fields correspond to those defined in `IServerRemoteContext` and `IClientRemoteContext`.
    *   **Message Encoding:** ICC messages (`icc.Message`) must be encoded using `string.buffer` and compressed (via `icc.StringBufferPeer`) when stored in shared memory, as OpenResty shared dictionaries only support string or number values in lists.
    *   **Asynchronous Delivery:** Use `ngx.thread.spawn` within websocket resources to create background loops that pop messages from shared memory queues and deliver them to clients.
*   **Test Files:** Test files are important and should not be deleted.
*   **EmmyLua Table Notation:** Prefer `{[KeyType]: ValueType}` notation for tables instead of `table<KeyType, ValueType>`.
*   **Variable Naming (Conflicts with Globals):** Avoid using Lua global names (e.g., `type`, `table`, `string`, `pairs`) for local variables. If you must use such a name, prefix it with an underscore (e.g., `_type`).

## Standards & Traceability

To ensure long-term maintainability and alignment between design and implementation, the following standards are established:

*   **Living Specifications:**
    *   New features or major changes MUST be documented in a `spec.md` file within the relevant module directory.
    *   **Structure**: A `spec.md` should lead with the **Goal** and **User Experience**, providing high-level context before diving into implementation details.
    *   **Architecture Decisions (ADR)**: Significant architectural choices should be documented directly within the `spec.md` in an `## Architecture Decisions` or `## ADR` section to keep context together.
    *   **Precise Terminology**: Avoid ambiguous terms. For example, do not use "difficulty" when referring to a chart variation or file; reserve it strictly for complexity metrics (star ratings, MSD, etc.).
*   **Traceability:**
    *   Specifications and code are linked using inlined tags (e.g., `[SPEC-MOD-01]`) within the documentation and as comments in the source code or tests.
    *   **Verification**: `scripts/check_spec_coverage.lua` is used to check coverage of specified requirements by searching for `[SPEC-*]` tags in both spec and code/test files.
*   **Documentation Locality:**
    *   Keep documentation as close to the code as possible.
    *   Use EmmyLua for API-level documentation.
    *   Use `spec.md` for behavioral and architectural documentation.

## Rizu Module Overview

The `rizu/` directory contains the modern, modular implementation of the game's core systems. It is organized into several key sub-modules:

*   **`rizu.engine`**: Low-level game logic and engine components.
    *   `RhythmEngine`: The core logic for processing notes and timing.
    *   `audio`: Modular audio system with backends (e.g., BASS).
    *   `visual`: Visual components like sprites and playfield rendering logic.
    *   `input`: Low-level input event handling (Physic and Virtual events).
*   **`rizu.gameplay`**: High-level management of gameplay sessions.
    *   `GameplaySession`: Coordinates the engine, players (manual/auto/replay), and recorders.
    *   `GameplayInteractor`: Bridges the game session with the UI and external services.
*   **`rizu.library`**: Manages the local chart database and collections.
    *   `Library`: Main entry point for chart discovery and management.
    *   `repos`: Database access layer (e.g., `ChartsRepo`, `CollectionsRepo`).
*   **`rizu.select`**: Logic for song and score selection.
    *   `ChartSelector`: Handles filtering, searching, and sorting of charts.
    *   `SelectionState`: Maintains the current user selection and navigation state.
*   **`rizu.preview`**: Handles audio, BGA, and note chart previews.
    *   `PreviewModel`: Coordinated preview system with master clock synchronization.
*   **`rizu.loop`**: The main game loop, update/draw cycles, and state management.
*   **`rizu.files`**: Resource loading, discovery, and file system abstractions.
*   **`rizu.game`**: Top-level game coordination and global timers.

### Performance & Benchmarking

The project prioritizes high-performance Lua code, especially within the gameplay engine.

*   **Benchmarking:** When making core changes, use isolated benchmark scripts (running with `luajit`) to verify that optimizations are not elided by the JIT and that they provide measurable improvements.

### Testing

The project uses a custom testing framework. Test files are first-class citizens and must be maintained rigorously.

1.  **File Naming:** Test files should be named with a `_test.lua` suffix and should reside in the same directory as the source file they test (e.g., `MyRepo.lua` -> `MyRepo_test.lua`).
2.  **Preservation:** NEVER delete test files during refactoring. If a module is moved or renamed, its corresponding tests must be moved and updated to reflect the new structure.
3.  **Verification:** ALWAYS run project-specific tests after making changes. Fulfill the user's request thoroughly by including automated tests; a change is incomplete without verification logic.
4.  **Structure:** A test file should return a table containing test functions. Each test function receives a `t` object of type `testing.T`.
5.  **Assertions:** Use the methods provided by the `t` object for assertions:
    *   `t:eq(got, expected, msg?)`: Equality check (`==`).
    *   `t:ne(got, expected, msg?)`: Inequality check (`!=`).
    *   `t:tdeq(got, expected, msg?)`: Deep equality check for tables. Can be used to compare `icc.Message` objects directly.
    *   `t:has_error(func, ...)`: Asserts that calling `func(...)` raises an error.
    *   `t:has_not_error(func, ...)`: Asserts that calling `func(...)` does not raise an error.
    *   `t:assert(cond, err_msg?)`: Basic assertion.

#### Testing Inter-Connection Communication

When testing code that sends messages to other connections (using `getPeers()`):
1. Use `FakeSharedDict` to simulate nginx shared memory.
2. Remember that inter-connection calls via shared memory queues are one-way. Use "no-return" remotes (e.g., `-remote`) to avoid yielding in contexts that don't support it.
3. Assert on the contents of the queue using `t:tdeq(popped, Message(...))`.

Example:

```lua
local MyModule = require("MyModule")
local test = {}

---@param t testing.T
function test.my_feature(t)
    t:eq(MyModule.add(1, 1), 2)
end

return test
```

### Web Development

The website is built with a custom Lua-based framework.

*   **Routing:** The `sea/` directory contains the web-related code. Routing is handled by "Resource" classes (e.g., `sea/shared/http/IndexResource.lua`). New routes can be added by creating a new resource and adding it to `sea/app/Resources.lua`.
*   **Templating:** The frontend uses `etlua` for templating, allowing Lua code to be embedded in HTML files.
*   **HTMX:** The frontend uses HTMX. For links that need to perform a full page navigation (like external links or redirects), you must add `hx-boost="false"` to the `<a>` tag to prevent HTMX from intercepting the click. For external links, using the full URL is sufficient.
*   **Markdown:** Wiki pages (`sea/wiki/`) are written in a Markdown dialect that is processed by `etlua`. This allows embedding Lua code, for example, to get configuration from `brand.lua`: `[link](<%= brand.url %>/some/path)`.
*   **Class Annotations:** EmmyLua annotations are used for classes. Web resources should have a class annotation following the pattern `---@class sea.MyResource: web.IResource`.

### Gameplay Architecture

The gameplay logic is centered around the single-play session attempt.

*   **`rizu.GameplaySession`**: The core logic for a single gameplay attempt. It coordinates the `RhythmEngine` (logic), `AutoplayPlayer`/`ReplayPlayer` (automated input), and `ReplayRecorder` (output).
    *   **Lifecycle**: A new instance of `GameplaySession` must be created for every play or retry. It is initialized with a `RhythmEngine` instance.
    *   **Play Types**: Use `setPlayType(type)` where type is `"manual"`, `"auto"`, or `"replay"`. This determines the source of input events and ensures exclusive update logic.
*   **`rizu.gameplay.GameplayInteractor`**: Acts as a bridge between the monolithic `GameController`/UI and the `GameplaySession`. It handles peripheral concerns like Discord Rich Presence, UI notifications, and starting/stopping the session.
*   **Rhythm Engine States**:
    *   `RhythmEngine:hasResult()`: Determines if the current play should produce a score. It requires a minimum hit count and valid accuracy.
    *   `autoplay` and `promode` flags are managed at the session level, not inside the core engine logic (though older `sphere` code might still have legacy flags).

### Audio Architecture

The `rizu` audio system follows a modular, interface-based design using the Provider pattern to support multiple backends.

*   **Core Interfaces**:
    *   `rizu.audio.IProvider`: Factory for creating decoders and sources.
    *   `rizu.audio.IDecoder`: Interface for decoding audio data into raw samples.
    *   `rizu.audio.ISource`: Interface for audio playback (play, pause, setRate, getPosition).
*   **Backends**:
    *   **`bass`**: The primary backend using the BASS library. Located in `rizu/engine/audio/bass/`.
    *   **`fake`**: A mock backend for testing or when audio is disabled. Located in `rizu/engine/audio/fake/`.
*   **Key Components**:
    *   `rizu.audio.Engine`: The main controller that coordinates background music (`source`) and foreground hitsounds (`foregroundSource`).
    *   `rizu.audio.SoftwareMixer`: A custom software-level mixer used for combining multiple audio streams (e.g., for rendering waveforms or O2Jam previews).
*   **Naming Convention**: Backend implementations are namespaced under their respective folders (e.g., `rizu.audio.bass.Decoder`, `rizu.audio.fake.Source`).

### SPH Chart Format

The `.sph` format is a text-based format for rhythm game charts.

*   **Notes Section**: Lines in the `# notes` section follow the format `"XXXX =Y"`.
    *   `XXXX`: A bitmask or representation of notes in columns.
    *   `Y`: The absolute time of the line in seconds.
*   **Timing**: The engine requires at least **two lines** in the `# notes` section to compute the timing and average beat duration (tempo). The SPH format **does not support explicit tempo declarations**; tempo is always computed based on the time difference between lines.

### Gameplay Testing Patterns

When writing tests for gameplay logic or the rhythm engine:

*   **Time Advancement**: Use `GameplaySession:update(global_time)` to advance time.
*   **Initialization Order**: Always set the global time (`re:setGlobalTime(t)`) before calling `re:play()` or `re:update()` to ensure internal timers are correctly initialized.
*   **TestChartFactory**: Use `sea.chart.TestChartFactory` for programmatic chart creation in tests. It produces minimal `Chart`, `Chartmeta`, and `Chartdiff` without parsing files.
    ```lua
    local TestChartFactory = require("sea.chart.TestChartFactory")
    local tcf = TestChartFactory()
    local res = tcf:create("4key", {
        {time = 1, column = 1}, -- Tap note
        {time = 2, column = 2, end_time = 3}, -- Long note
        {time = 4, velocity = {0.5}}, -- SV change (current=0.5, local=1, global=1)
    })
    -- Use res.chart, res.chartmeta, res.chartdiff
    ```
