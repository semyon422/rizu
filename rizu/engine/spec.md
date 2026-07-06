# Engine And Audio Architecture (`rizu.engine`)

## Goal
The engine module provides the low-level runtime systems for rhythm processing, audio playback, rendering support, and input plumbing. It should remain modular, backend-friendly, and efficient enough for real-time gameplay.

## User Experience
- Timing and judgment should feel consistent and precise.
- Audio should remain synchronized with gameplay across supported backends and playback rates.
- Engine-level changes should not introduce frame drops, audio desync, or hidden state carried across sessions.

## Module Areas

- `RhythmEngine`: core note processing and timing logic.
- `ScoreEngine`: scoring systems, judge counters, accuracy, combo, health, and score source interfaces.
- `audio/`: provider-based audio backend system.
- `visual/`: low-level rendering and playfield support.
- `input/`: physical and virtual input event handling.

## Architecture Decisions

### ADR: Provider-Based Audio Backends
- Audio backends implement interface-based contracts instead of hard-coding a single implementation.
- Core interfaces:
  - `rizu.audio.IProvider`
  - `rizu.audio.IDecoder`
  - `rizu.audio.ISource`
- Current backends:
  - `rizu.audio.bass.*` for the primary BASS implementation, with BASS_FFMPEG plugin decoding
  - `rizu.audio.fake.*` for testing or disabled-audio scenarios

### ADR: Central Audio Engine Coordination
- `rizu.audio.Engine` coordinates background playback and foreground hitsounds.
- `rizu.audio.SoftwareMixer` is used when multiple streams need software-level combination, such as waveform rendering or preview workflows.

### ADR: Streaming Decode Stays In BASS Channels
- Runtime playback uses BASS streams so encoded files are decoded on demand instead of fully decoded before playback.
- The BASS_FFMPEG plugin lets BASS streams decode through FFmpeg while preserving BASS mixer, tempo, seeking, and keysound behavior.

### ADR: Session-Level Policy Outside Core Timing
- Flags such as autoplay or promode should be coordinated by higher-level gameplay/session code where possible, even if legacy paths still exist elsewhere.

## Performance Notes

- Treat gameplay and audio code as performance-sensitive by default.
- When optimizing core loops, use focused benchmarks with `luajit` where a normal test run would not show timing regressions clearly.
- Prefer simple data flow and avoid unnecessary allocation in per-frame or per-note paths.

## Verification

- Run focused tests in `rizu/engine` or adjacent modules after changes.
- If an engine change affects gameplay semantics, also run the relevant gameplay tests.
