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
- **Decision**: `BgaPreviewPlayer` uses `AsyncVideoEngine`, which runs `AsyncVideoWorker.lua` in a LÖVE thread. The worker reads video files through the virtual filesystem, opens them with the FFmpeg-backed `video` module, decodes batches of `ImageData`, and sends decoded frames back to the main thread.
- **Consequence**: The main thread only drains decoded frames and uploads the currently displayed frame to the GPU. `readAt` is used only for the first frame of a batch after a real seek or jump; sequential frames use `read()` to preserve decoder state. Queue resets must allow a small half-frame presentation lead so normal frame selection is not mistaken for a backward seek.

## Implementation Details

### Components
- **PreviewModel**: The central coordinator. Manages the master clock, looping range, and loading states.
- **Notes Preview**: A high-performance string representation of notes stored in the database for instant retrieval.
- **Audio/BGA Previews**: Dedicated event collections stored in `.audio_preview` and `.bga_preview` files within `userdata/`.
  - **Unified Audio**: The system does not distinguish between single-file audio (osu!) and multi-sample backgrounds (BMS). All audio is treated as a sequence of events (sample index, time, duration, volume).

### Looping Algorithm
- **Start Position**: Defined by `preview_time` metadata. If missing, it defaults to the absolute start time of the audio events (which may be non-zero).
- **Looping Range**: The loop is determined by the **Audio Start Time** and **Audio End Time**. This range is distinct from the chart's `duration` field, which only tracks note data.
- **End Behavior**: When the master clock reaches the audio end time, it restarts exactly from the audio start time.
- **Audio Constraints**: If the audio preview is missing or its total duration is 0, the preview playback is automatically paused to prevent invalid state.

### Preview Types
- **Audio**: Scans for all hitsounds and background music events across all formats to create a flattened event sequence.
- **BGA**: Scans for layer changes and video triggers.
- **Notes**: Encodes a simplified bitmask of column activity over time.
