# Plugins

A plugin is a package: a folder or `.zip` in `userdata/pkg` with a `pkg.json`. Its `types` say what it adds:

- `ui`: a module returning a `rizu.app.UserInterface` class.
- `require`: a module the game requires at start, in the main thread and in every worker thread, before the library loads. Plugins register things from here, or patch the game.

## Interface

`ui.Extensions.add(function(ui) ... end)` from the `require` module extends the default interface. It runs every time the interface loads, once its screens and commands exist:

- `ui.screen_manager:register(screen)` and `ui:setScreen(screen)` for a screen of the plugin's own.
- `ui.command_registry:pushContext("my_plugin", commands)` for commands in the command palette.
- Existing screens, such as `ui.song_select`, can be patched from here.

An error in the function is shown as a notification, and the rest of the interface loads.

