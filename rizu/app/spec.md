## Goal

The `rizu/app/` module owns runtime application wrappers around LÖVE window, audio device, screenshots, cursor setup, and Discord presence.

## User Experience

- Window, cursor, screenshot, audio device, and Discord behavior should follow persisted settings and remain responsive during gameplay and selection.
- Screenshots should save to the user screenshots directory and optionally open in the platform file manager.

## Architecture Decisions

- `App` composes small runtime models and is owned by `GameController`.
- `WindowModel` is the central place for window mode, fullscreen, vsync, cursor, icon, and loop FPS policy synchronization.
- `DiscordModel` gates all Discord RPC work behind the persisted presence setting.
- `UserInterface` bridges the game controller and package mount path into the reusable `gui.UserInterface` lifecycle.
- `UserInterfaceManager` discovers built-in and packaged UI factories, resolves the selected UI setting, and installs the resulting instance on `GameController`. UI selection belongs here rather than in the generic GUI module because it depends on game settings and `rizu.pkg.PackageManager`.

## Invariants

- `WindowModel` is also used during update startup before the full game controller is loaded.
- Cursor creation depends on an active LÖVE graphics context.
- The built-in UI is always registered as the fallback when a configured package is unavailable.
