# Rizu Build System Specification

## Goal
The goal of the Rizu build system is to provide a reliable, automated, and cross-platform environment for managing dependencies, compiling native modules, and packaging the game into distributable formats. It ensures a consistent build process for all developers and CI/CD pipelines.

## User Experience
- **Simplicity**: A single entry point (`./build/make.lua`) handles the entire lifecycle.
- **Portability**: The build system runs on Ubuntu (host) and targets Linux, Windows, and macOS.
- **Efficiency**: Incremental builds skip already completed and up-to-date tasks.
- **Modularity**: New build steps or dependencies can be added by creating a new task class.

## Architecture Decisions (ADR)
- **Task-Based Engine**: The system uses a dependency-aware `TaskRunner`. Each task is a class implementing `run(ctx)` and `upToDate(ctx)`.
- **Context Abstraction**: A `Context` object abstracts the filesystem, shell, and downloader. This decouples the build logic from the host OS and enables isolated testing with mock contexts.
- **LuaJIT-Powered**: The build system itself is written in Lua and runs on the system's LuaJIT, ensuring high performance and ease of maintenance.
- **Cross-Compilation Strategy**:
    - **Windows**: Uses `x86_64-w64-mingw32-gcc` on Linux.
    - **macOS**: Uses `osxcross` toolchain. Due to proprietary SDK requirements, this requires a manual step of providing the Xcode `.xip` file.
- **External Dependency Management**: Binary dependencies (FFmpeg, 7z SDK) are fetched from official sources and cached locally to ensure reproducible builds.

## Directory Structure
- `build/`: Core build system directory.
    - `tasks/`: Task implementations (e.g., `FetchDeps.lua`, `BuildModules.lua`).
    - `package/`: Templates and logic for platform-specific packaging (e.g., `RepoBuilder.lua`, `Info.plist`).
    - `downloads/`: Cache for downloaded archives and assets.
    - `deps/`: Extracted and prepared third-party libraries.
    - `spec.md`: This specification.
    - `make.lua`: Main entry point and task orchestrator.
    - `Builder.lua`: High-level logic for C module compilation.
- `bin/`: Final binary artifacts (e.g., `.so`, `.dll`, `.dylib`) organized by platform.
- `repo/`: Distributable packages (ZIP archives) and update repository metadata. Moved to `build/repo/`.

## Task Lifecycle & Dependencies
The build process follows a strictly defined dependency graph:

1.  **`setup_host`**: Installs essential system tools (e.g., `curl`, `7z`, `build-essential`).
2.  **`setup_luajit_<target>`**: Compiles and installs the LuaJIT runtime for the target platform.
3.  **`deps_<target>`**: Fetches and prepares binary dependencies (FFmpeg, 7z SDK).
4.  **`build_<target>`**: Compiles native C modules (`video.c`, `7z.c`) using the target's cross-compiler. Depends on `deps_<target>`.
5.  **`package`**: Bundles source code, binaries, and resources into platform-specific archives. Depends on successful builds.
6.  **`repo`**: Generates `files.json` and `files.lua` for the built-in updater system.

## Implementation Details
- **`Builder:getCompiler()`**: Automatically selects the correct cross-compiler based on the target.
- **`RepoBuilder`**: Handles the heavy lifting of gathering files, zipping `game.love`, and preparing the macOS `.app` bundle structure.
- **Incremental Logic**: `BuildModules:upToDate` compares modification times of source files vs. binary artifacts to avoid redundant compilation.

## Verification
- **Dry-Run Tests**: Packaging logic should be verifiable using a mock filesystem to ensure correct file placement without writing to disk.
- **Target Validation**: Each built binary should be verified by the build system (e.g., checking if the output file exists and has the correct architecture).
- **Update Integrity**: `BuildRepo` generates CRC32 hashes for all files, which are used by the game client to verify updates.
