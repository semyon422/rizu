# UI for Rizu

User interface module for Rizu. Uses "gui" module. Exists on it's own, but goes to GameController to take some data from the game, to become a listener of some events, read and writes configs or calls methods that can change the game behavior.

## Structure

### Directories
- `/`: A dump for everything
- `views/`: Generic views that can be used everywhere. Add views here if not sure where to put them.
- `screens/`: Screens together with their views.
- `formatters/`: Formatting info from the game. Works only with this UI, you can copy paste it into your UI and slightly change it to make it work.
- `test/`: A collection of test views used to test "gui" module and views from this module.

### Userful files
- `UserInterface.lua`: Entry point for this UI
- `Resources.lua`: Singleton class that loads and stores fonts and sprites
- `Colors.lua`: Colorscheme table
- `Color.lua`: Utils for working with colors
- `Sounds.lua`: Singleton that can play sounds

## UI actions and key bindings

`gui.input.ActionMap` maps semantic action names to one or more keyboard bindings. UI code asks whether an input event matches an action instead of checking LÖVE keys directly:

```lua
if inputs:consumeActionJustPressed(UiActions.cancel) then
	closeModal()
end
```

`ui.UiActions` owns UI-specific action names and maps the key-binding settings in `ui.UiConfig` into the generic action map. `gui.Inputs` exposes `isActionPressed`, `isActionJustPressed`, and `isActionJustReleased`; `consumeActionJustPressed` / `consumeActionJustReleased` remove an edge after a higher-priority handler claims it, and all remaining `just` states reset at the start of each frame. `defineAction` replaces an action's bindings, `addBinding` adds an alternative, `getBindings` supports settings UI, and `getBindingLabel` provides display text. Bindings use exact modifiers and ignore key-repeat unless `allow_repeat = true`. Mouse wheel bindings use the keys `wheelup`, `wheeldown`, `wheelleft`, and `wheelright`; they produce a pressed edge only, since wheel input is not held.

Queued events update action state before raw event routing, including events consumed by screen-level handlers. Gameplay input remains separate.

## Guidelines

We use sprites for most things. Try to batch as much as we can using love's automatic batching or sometimes use TextBatch and SpriteBatch. Spamming a lot of views should be okay, but you can always make a single view which can for example display a lot of info using TextBatch or SpriteBatch or even automatic batching works okay here.

Do not use love.graphics.rectangle() if you draw visible rectangles. Use love.graphics.draw(Resources.sprites.pixel, 0, 0, 0, width, height). love.graphics.rectangle() is okay for stencils. And don't even thing about using love.graphics.rectangle() to make rounded rectangles, they look horrible.

Do not reference any class from this UI in "rizu" or "gui" or any other modules. If you need to, then something is wrong and it is time to start complain and refactor. This is frontend, it's completely separate from the backend.
