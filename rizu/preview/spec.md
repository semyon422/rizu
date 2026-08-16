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
- **Consequence**: The main thread only drains decoded frames and uploads the currently displayed frame to the GPU. `AsyncVideoEngine` depends on `IAsyncVideoTransport` and `IAsyncVideoLogger` so thread/channel wiring and diagnostics can be tested with fake implementations. `readAt` is used only for the first frame of a batch after a real seek or jump; sequential frames use `read()` to preserve decoder state. Queue resets must allow a small half-frame presentation lead so normal frame selection is not mistaken for a backward seek. If the preview clock asks for a video time beyond the resource duration, the worker sends the final decoded frame as an ended frame and the main thread holds it instead of repeatedly seeking past EOF.

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
- **Audio decode buffering**: preview decoder requests must fill the configured buffer rather than use frame-sized chunks. Thread-remote responses are serviced by the main update loop, so decode throughput must not depend on rendering frame rate.
- **Preview activation source**: select preview loading is triggered only from a non-empty `chartview_changed` event. Select screen entry may re-announce the currently loaded chartview, but `SelectionCoordinator:load()` must not start preview directly.
- **Async video queue order**: `AsyncVideoEngine` expects queued video frames to be monotonic by `frame_time`. Non-monotonic frames are logged because they can cause visible skips or stale presentation.
- **Async video frame ownership**: decoded `ImageData` is owned by the main thread after it is received from the worker. The main thread must either upload it to the `Image` or release it when it is stale, dropped, or superseded.
- **Async video backpressure**: each video has at most one pending worker request. A newer desired time replaces older intent, and stale generation/request responses must not affect current state.
- **Async video queue resets**: queue resets are reserved for real backward seeks, stale batches behind the playback clock, or obsolete future batches. Normal fractional timer jitter around the displayed frame must not be treated as a seek.
- **Async video decoder state**: `readAt` is intentionally rare because it flushes FFmpeg decoder state and caused visible preview stutter when used for ordinary playback. After the initial frame of a batch, or after a real seek/jump, sequential frames must use `read()` so decoder state stays warm.
- **Async video EOF handling**: a request beyond the video's duration must not create a `readAt`/`read_miss` retry loop. The worker should decode the final available frame, report it as `ended`, and the main thread should stop requesting later frames until the playback clock seeks backward.
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

### BGA Video Playback
Select preview and gameplay now share the low-level `AsyncVideoEngine` decode and presentation pipeline. Their BGA event ownership remains separate: `BgaPreviewPlayer` owns preview events, while gameplay keeps `BgaEngine` and its session timing/lifetime.

Some imported libraries can contain unusual or stale `preview_time` metadata. The async video pipeline now handles video times beyond EOF by holding the final frame, but metadata normalization may still be worth revisiting if a format consistently stores preview offsets in unexpected units.

`sphere.views.BgaView` currently chooses between gameplay BGA and select-preview BGA in one shared draw path. This couples two different lifecycles and two different video backends, so it is easy for stale gameplay state to affect result or select screens. Refactor it later so gameplay and preview BGA presentation are owned by separate view paths or by an explicit presentation interface.
