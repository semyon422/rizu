# Preview System (`rizu.preview`)

## Goal
The preview system provides players with an immediate sensory snapshot of a song before they commit to playing it. By synchronizing simplified note visuals, full audio playback, and background animations (BGA), it creates an "alive" selection experience that helps players identify songs and evaluate their difficulty.

## User Experience
- **Instant Feedback**: Selecting a song in the menu immediately triggers its preview. The playback starts at the song's most representative section (defined by metadata) and loops according to the audio content's duration.
- **Visual Context**: A simplified "mini-playfield" renders the chart's notes, while any background images or videos are displayed in the preview area.
- **Dynamic Response**: If the player changes the playback rate (e.g., to 1.5x) in the selection screen, the preview audio and visuals speed up accordingly to match the intended gameplay experience.
- **Seamless Loading**: Previews are generated and cached in the background. If a preview isn't ready, the system stays silent and waits without blocking menu navigation or causing micro-stutters.

## Architecture Decisions (ADR)

### ADR: Model-Player Pattern
- **Context**: The preview involves multiple independent systems (Audio, Video, Sprite, Visual) that must stay perfectly synchronized to a single master clock.
- **Decision**: We use a central `PreviewModel` to manage the master clock and playback state, which then drives specialized "Player" components (`NotesPreviewPlayer`, `AudioPreviewPlayer`, `BgaPreviewPlayer`).
- **Consequence**: This separation ensures that logic for time management is decoupled from specific rendering or audio backends, making the system easier to test and extend.

### ADR: Off-Thread Preview Generation
- **Context**: Generating preview files requires parsing full chart files and scanning for thousands of audio/visual events, which can take several hundred milliseconds.
- **Decision**: All preview generation is performed as an asynchronous task in a separate thread. Results are cached in `userdata/` using the chart's content hash.
- **Consequence**: The main UI thread remains completely unblocked, ensuring the library browsing experience remains fluid even for new or un-cached content.

### ADR: Async BGA Video Playback
- **Context**: Preview videos can be large and expensive to decode. Decoding or seeking them on the main thread causes visible stutter while scrolling charts.
- **Decision**: `BgaPreviewPlayer` uses `AsyncVideoEngine`, which runs `AsyncVideoWorker.lua` in a LÖVE thread. The worker opens video files through `video.openPath(path)`, which uses PhysFS-backed FFmpeg AVIO callbacks for virtual filesystem reads. The worker decodes batches of `ImageData` and sends decoded frames back to the main thread.
- **Consequence**: The main thread only drains decoded frames and uploads the currently displayed frame to the GPU. `AsyncVideoEngine` depends on `IAsyncVideoTransport` and `IAsyncVideoLogger` so thread/channel wiring and diagnostics can be tested with fake implementations. `readAt` is used only for the first frame of a batch after a real seek or jump; sequential frames use `read()` to preserve decoder state. Queue resets must allow a small half-frame presentation lead so normal frame selection is not mistaken for a backward seek.

## Implementation Details

### Components
- **PreviewModel**: The central coordinator. Manages the master clock, looping range, and loading states.
- **Notes Preview**: A high-performance string representation of notes stored in the database for instant retrieval.
- **Audio/BGA Previews**: Dedicated event collections stored in `.audio_preview` and `.bga_preview` files within `userdata/`.
  - **Unified Audio**: The system does not distinguish between single-file audio (osu!) and multi-sample backgrounds (BMS). All audio is treated as a sequence of events (sample index, time, duration, volume).
- **Async Video Policies**: `AsyncVideoQueue` owns queue reset/prefetch invariants, while `AsyncVideoReadPolicy` owns the `readAt` vs `read` decision. These modules intentionally avoid LÖVE state so timing behavior can be regression-tested directly.
- **Async Video Transport**: `AsyncVideoThreadTransport` is the production LÖVE thread/channel implementation of `IAsyncVideoTransport`; tests use fake transports to exercise `AsyncVideoEngine` as a state machine without spawning a worker.
- **PhysFS Video Input**: `video.openPath(path)` lives in the FFmpeg-backed native video module. It resolves PhysFS symbols from the LÖVE runtime at load time, opens virtual paths with `PHYSFS_openRead`, and lets FFmpeg pull chunks through custom AVIO read/seek callbacks.

### Invariants
- **Preview clock ownership**: `PreviewModel` owns the master preview time. Audio, notes, and BGA players are driven from that clock and should not advance their own independent playback time.
- **Async video queue order**: `AsyncVideoEngine` expects queued video frames to be monotonic by `frame_time`. Non-monotonic frames are logged because they can cause visible skips or stale presentation.
- **Async video frame ownership**: decoded `ImageData` is owned by the main thread after it is received from the worker. The main thread must either upload it to the `Image` or release it when it is stale, dropped, or superseded.
- **Async video backpressure**: each video has at most one pending worker request. A newer desired time replaces older intent, and stale generation/request responses must not affect current state.
- **Async video queue resets**: queue resets are reserved for real backward seeks, stale batches behind the playback clock, or obsolete future batches. Normal fractional timer jitter around the displayed frame must not be treated as a seek.
- **Async video decoder state**: `readAt` is intentionally rare because it flushes FFmpeg decoder state and caused visible preview stutter when used for ordinary playback. After the initial frame of a batch, or after a real seek/jump, sequential frames must use `read()` so decoder state stays warm.
- **Thread boundary**: the worker may read virtual paths and decode frames, but the main thread remains responsible for GPU image creation/replacement. The main thread should not decode video frames.
- **Thread lifecycle**: async video workers must be registered as managed threads in `ThreadPool` so shutdown/quitting code can see and stop them. A transport should unregister only after the underlying worker is no longer running, unless it never started or already finished.

### Looping Algorithm
- **Start Position**: Defined by `preview_time` metadata. If missing, it defaults to the absolute start time of the audio events (which may be non-zero).
- **Looping Range**: The loop is determined by the **Audio Start Time** and **Audio End Time**. This range is distinct from the chart's `duration` field, which only tracks note data.
- **End Behavior**: When the master clock reaches the audio end time, it restarts exactly from the audio start time.
- **Audio Constraints**: If the audio preview is missing or its total duration is 0, the preview playback is automatically paused to prevent invalid state.

### Preview Types
- **Audio**: Scans for all hitsounds and background music events across all formats to create a flattened event sequence.
- **BGA**: Scans for layer changes and video triggers.
- **Notes**: Encodes a simplified bitmask of column activity over time.

## Future Work and Open Questions

### BGA Video Playback Roadmap
The target model for preview video is: video data is read off the main thread, decoded off the main thread, and decoded frames are sent back to the main thread for presentation. File access goes through `love.filesystem`/PhysFS-compatible virtual paths so mounted chart resources, archives, and normal filesystem paths all behave the same.

The work should stay incremental so each step can be validated in-game before adding the next layer of complexity:

1. **Worker decode with memory-backed video data**
   - Goal: prove the architecture where decoding runs in a worker and the main thread receives decoded frames.
   - Worker reads the virtual path with `love.filesystem.read(path)`.
   - Worker opens the video with `video.open(pointer, size)`.
   - Main sends requests such as `name`, `time`, and `generation`.
   - Worker seeks/reads and returns decoded frame data with `name`, `time`, `frame_time`, `width`, `height`, and image payload.
   - Validation: BGA preview video does not freeze the main thread during seek/play, stale generations are ignored, and fast chart scrolling does not crash.

2. **Request protocol and backpressure**
   - Goal: avoid filling channels or memory with obsolete decoded frames.
   - Each video should have bounded pending work.
   - New desired times should supersede stale requests.
   - The main thread should apply a returned frame only if `generation`, `name`, and request identity are still current.
   - Validation: fast seek/scroll does not make video visibly catch up to old times, and memory does not grow from queued frames.

3. **Path-based C API backed by PhysFS**
   - Status: implemented.
   - Goal: stop loading entire video files into memory.
   - `video.openPath(path)` in `aqua/video.c` uses `PHYSFS_openRead(path)` plus a custom FFmpeg `AVIOContext` with read/seek/tell callbacks.
   - PhysFS symbols are resolved from the LÖVE runtime dynamically so the module does not require direct PhysFS linkage.
   - Validation: `video.openPath("mounted_charts/.../bga.mp4")` should work for virtual paths, archives, and ordinary mounted paths, with seek/readAt behavior matching the memory-backed decoder.

4. **Switch the worker from read-whole-file to openPath**
   - Status: implemented for preview worker.
   - Worker receives virtual paths.
   - Worker opens video through `video.openPath(path)`.
   - FFmpeg reads chunks through PhysFS callbacks.
   - Worker still decodes frames and main still receives decoded images.
   - Validation: large videos are not loaded entirely into memory, mounted chart paths work, and fast scrolling releases old decoders.

5. **Keep integration scoped to preview first**
   - Goal: improve select preview without changing gameplay BGA behavior.
   - Apply async video to `BgaPreviewPlayer` first.
   - Keep `BgaView` drawing `video.image` through the existing drawable path.
   - Validation: select preview is smoother, gameplay BGA remains unchanged, and only after that should gameplay video reuse be considered.

6. **Cleanup, tests, and commits**
   - Suggested commit sequence:
     - async video worker with memory-backed decode,
     - request/backpressure protocol,
     - PhysFS-backed `video.openPath`,
     - worker switch to `openPath`,
     - cleanup and regression tests.
   - This keeps a safe ladder: first prove worker decode helps, then separately tackle the riskier PhysFS/FFmpeg callback layer.
