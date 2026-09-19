## Goal

The `rizu/app/` module owns runtime application wrappers around LÖVE window, audio device, screenshots, cursor setup, and Discord presence.

## User Experience

- Window, cursor, screenshot, audio device, and Discord behavior should follow persisted settings and remain responsive during gameplay and selection.
- Screenshots should save to the user screenshots directory and optionally open in the platform file manager.

## Architecture Decisions

- `App` composes small runtime models and is owned by `GameController`.
- `AudioModel` resolves restart-applied latency presets to BASS device period/buffer pairs. The System preset preserves the platform defaults or existing advanced numeric values; lower-latency presets trade output stability for faster live keysounds. It also owns output-device discovery/status and Linux backend selection. PipeWire Low Latency uses BASS's PipeWire ALSA endpoint plus a process-local `PIPEWIRE_LATENCY` quantum request. Unavailable or failed endpoints fall back to the default device and retain a visible startup diagnostic.
- `WindowModel` is the central place for window mode, fullscreen, vsync, cursor, icon, and loop FPS policy synchronization.
- `DiscordModel` gates all Discord RPC work behind the persisted presence setting.
- `UserInterface` bridges the game controller and package mount path into the reusable `gui.UserInterface` lifecycle.
- `UserInterfaceManager` discovers built-in and packaged UI factories, resolves the selected UI setting, and installs the resulting instance on `GameController`. UI selection belongs here rather than in the generic GUI module because it depends on game settings and `rizu.pkg.PackageManager`.

## Invariants

- `WindowModel` is also used during update startup before the full game controller is loaded.
- Cursor creation depends on an active LÖVE graphics context.
- The built-in UI is always registered as the fallback when a configured package is unavailable.
- Audio backend selection must preserve `rizu.audio.Engine` and its background/foreground mixer split; output transport changes must not reintroduce direct sample playback as a separate keysound architecture.

## Future Work and Open Questions

### Native PipeWire backend

Add `pipewire_native` as another persisted backend rather than replacing BASS Default or PipeWire Low Latency. Unlike the interim PipeWire option, it needs a packaged native module that owns PipeWire's real-time process callback; Lua must not run on that callback. The module should accept bounded float32 stereo blocks from a single master output stream, negotiate the device sample rate/quantum, report presented-frame position and measured output latency, and expose underrun counters. Background audio and dynamic keysounds must continue through the existing mixer path before reaching that transport. Backend/device enumeration should use stable PipeWire node identities and retain the restart-applied switching contract.

### Windows low-latency backends

Add backend choices only after their native dependencies and redistribution terms are included in the Windows build. Implement WASAPI Exclusive first: enumerate stable endpoint IDs, negotiate shared device formats, use event-driven rendering on a native real-time thread, report device padding/latency, and recover cleanly from endpoint changes or exclusive-access failure. Keep BASS Default as the fallback. ASIO can follow as an expert option; it additionally needs driver enumeration, channel-pair selection, sample-format conversion, buffer-size negotiation, and explicit handling for single-client drivers. Both transports must consume the same master mixed stream as PipeWire rather than bypassing the keysound mixer.
