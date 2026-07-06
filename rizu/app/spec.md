## Goal

The `rizu/app/` module owns runtime application wrappers around LÖVE window, audio device, screenshots, cursor setup, and Discord presence.

## User Experience

- Window, cursor, screenshot, audio device, and Discord behavior should follow persisted settings and remain responsive during gameplay and selection.
- Screenshots should save to the user screenshots directory and optionally open in the platform file manager.

## Architecture Decisions

- `App` composes small runtime models and is owned by `GameController`.
- `WindowModel` is the central place for window mode, fullscreen, vsync, cursor, icon, and loop FPS policy synchronization.
- `DiscordModel` gates all Discord RPC work behind the persisted presence setting.

## Invariants

- `WindowModel` is also used during update startup before the full game controller is loaded.
- Cursor creation depends on an active LÖVE graphics context.
