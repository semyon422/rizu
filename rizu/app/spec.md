## Goal

The `rizu/app/` module owns runtime application wrappers around LÖVE window, audio device, screenshots, cursor setup, and Discord presence.

## User Experience

- Window, cursor, screenshot, audio device, and Discord behavior should follow persisted settings and remain responsive during gameplay and selection.
- Screenshots should save to the user screenshots directory and optionally open in the platform file manager.

## Architecture Decisions

- `App` composes small runtime models and is owned by `GameController`.
- `AudioModel` resolves restart-applied latency presets to device period/buffer pairs and publishes the process-wide gameplay output configuration. The System preset preserves the platform defaults or existing advanced numeric values; lower-latency presets trade output stability for faster live keysounds. Linux backends are BASS Default, BASS through its PipeWire ALSA endpoint, and SDL3 Native PipeWire. Unavailable or failed explicit backends fall back to BASS Default and retain a visible startup diagnostic.
- `WindowModel` is the central place for window mode, fullscreen, vsync, cursor, icon, and loop FPS policy synchronization.
- `DiscordModel` gates all Discord RPC work behind the persisted presence setting.
- `UserInterface` bridges the game controller and package mount path into the reusable `gui.UserInterface` lifecycle.
- `UserInterfaceManager` discovers built-in and packaged UI factories, resolves the selected UI setting, and installs the resulting instance on `GameController`. UI selection belongs here rather than in the generic GUI module because it depends on game settings and `rizu.pkg.PackageManager`.

## Invariants

- `WindowModel` is also used during update startup before the full game controller is loaded.
- Cursor creation depends on an active LÖVE graphics context.
- The built-in UI is always registered as the fallback when a configured package is unavailable.
- Audio backend selection must preserve `rizu.audio.Engine` and its background/foreground mixer split; output transport changes must not reintroduce direct sample playback as a separate keysound architecture.
- `love.audio` is disabled in `conf.lua`; runtime playback is owned by BASS, so LÖVE must not initialize a second OpenAL output stream. The prebuilt LÖVE runtime still links and packages OpenAL Soft and cannot drop that binary dependency without a custom LÖVE build.
- LÖVE 12 ships SDL3. The `sdl3_pipewire` backend uses its native PipeWire audio driver for the gameplay master stream. BASS remains initialized during this prototype for preview and focused UI sample paths that have not yet moved onto the shared master output.

## Future Work and Open Questions

### Native output hardening

Move preview and focused UI sample playback through the shared master output so SDL3 mode no longer keeps an idle BASS device output initialized.

Remove frame-rate dependence with a dedicated native audio worker. A callback-only PCM ring buffer is insufficient because Lua would still produce PCM from `Engine:update()` and could starve the ring during a long frame. The worker should own the BASS decode/master graph, continuously render bounded float32 stereo blocks, and feed an SPSC ring consumed by SDL's real-time callback. The main Lua thread should communicate through a lock-free command queue for timestamped sample starts, play/pause, seek, rate, and volume changes; Lua must never run on the callback. Report presented-frame position, measured output latency, command-to-output timing, and authoritative underrun counters. Input-event timestamps should allow the worker to schedule keysounds against its audio clock instead of quantizing sample starts to the next render update.

Backend/device enumeration should retain stable platform device identities and restart-applied switching. The same worker/output contract should support SDL PipeWire on Linux and later SDL WASAPI/CoreAudio transports.

### Windows low-latency backends

Add backend choices only after their native dependencies and redistribution terms are included in the Windows build. Implement WASAPI Exclusive first: enumerate stable endpoint IDs, negotiate shared device formats, use event-driven rendering on a native real-time thread, report device padding/latency, and recover cleanly from endpoint changes or exclusive-access failure. Keep BASS Default as the fallback. ASIO can follow as an expert option; it additionally needs driver enumeration, channel-pair selection, sample-format conversion, buffer-size negotiation, and explicit handling for single-client drivers. Both transports must consume the same master mixed stream as PipeWire rather than bypassing the keysound mixer.
