---
name: creating-rizu-user-interface
description: Use when designing and building a complete custom Rizu user interface (song select, gameplay, result, settings) as a `ui` plugin, especially when generating one with an AI agent ("vibecoding"). Covers the decisions to make first, the screen list, what each screen needs, and performance rules.
---

# Creating a Rizu User Interface

A custom UI is a `ui` plugin. For the package layout, `pkg.json` and the `rizu.app.UserInterface` class, read the `creating-rizu-plugins` skill first. This skill is about what to build and how to decide.

## Ground rules

- **Use the Game API.** `self.api` (`rizu.api.GameApi`) is the stable contract. Read `rizu/api/README.md`, then the comment at the top of each `rizu/api/*.lua` file: every function is documented there. Reach for `self.game` (the whole `GameController`) only for what the API does not cover; it can change without notice and break the plugin.
- **Develop against the fake game.** `./ui-preview <module>` runs the UI on `rizu.api.fake`, so no real game is needed. `self.game` is `nil` there, another reason to stay on the API. Check `api.version`.
- **Any UI library works.** The built-in `gui` module (retained tree of `View`s, see the `developing-rizu-ui` skill) is good but has flaws. Immediate-mode (imgui style) and plain retained code both work. Pick what you can make correct fastest. For vibecoding, immediate-mode with plain LÖVE calls is usually the simplest to generate and debug.
- **A UI can be anything.** It is not limited to menus: minigames, new mechanics, gacha, whatever. The screens below are the minimum to play the game.
- **This is a game, not a website.** Gameplay must run as fast as possible. Every other screen may have expensive layout and rendering, so do not trade looks for speed there, but never let it cost frames in gameplay.

## Decide first: how to draw

Choose before writing screens, because everything else follows:

1. **Panels/buttons look:** sprites (nine-slices, images), plain LÖVE rectangles, or SDF shaders (rounded corners, glow, borders without textures).
2. **Sprites: batch or not.** Use `love.graphics.newSpriteBatch` / atlases when many sprites share a texture (long lists, carousels). Skip batching when there are few elements; it only adds complexity.

State the choice (and the UI library) at the top of the UI's README, then stay consistent. Plain rectangles/SDF need no assets; sprites need assets loaded via `self.mount_path`.

## Design and assets

Pick a visual direction before coding (mood, 2-3 colors, one accent, shape language) and write it down next to the drawing choice. A game UI needs a recognisable look, not default gray boxes.

- **Fonts.** Download one or two fonts from the internet instead of using the LÖVE default. Use freely licensed ones (e.g. Google Fonts, SIL OFL), put the `.ttf`/`.otf` and its license file in the package, and load them via `self.mount_path`. Chart titles and artists are often CJK or otherwise non-Latin, so add a fallback: `font:setFallbacks(cjk_font)`. The game ships `resources/fonts/NotoSansCJK-Regular.ttc` that can be used for that. Create fonts once in `load()`, never per frame.
- **Generated sprites.** If the harness can generate images, use it for backgrounds, textures, icons and logos. Ship the final files in the package, not prompts or URLs. Keep sizes reasonable and prefer PNG, power-of-two sizes are not required.
- **Hand-drawn sprites via SVG.** An agent can write SVG for icons, panels, buttons and borders, then rasterize to PNG at build time (`rsvg-convert`, `inkscape --export-type=png`, or ImageMagick). LÖVE cannot load SVG, so commit the PNGs (and the `.svg` sources next to them). Rasterize at 2x of the largest size you draw, and scale down with a linear filter. Panels and buttons should be nine-slices so they stretch without distortion.
- **No assets at all** is a valid style: rectangles and SDF shaders give crisp, resolution-independent shapes and need nothing downloaded.
- Do not fetch anything from the network at runtime. All fonts and images must be inside the package.
- Check legibility at the real window sizes, and make sure text on top of chart backgrounds stays readable (dim or blur the background, add a panel behind text).

## Required screens

1. **Song select**
2. **Gameplay**
3. **Result**
4. **A small settings screen** with at least a way back to the default UI (`api.app:setUserInterface("rizu")` then `api.app:requestReload()`; check the default UI's `name` in `ui/UserInterface.lua`). Required during development: the default UI exposes every setting, so a broken custom UI must always be escapable. Add this first.

Navigation between them is yours: a `screen` variable or a screen manager. Start a play with `api.play:start(opts, function(ok, err) ... end)`; show `err` on failure.

## Song select

Everything is optional. Add only what you need. By priority:

1. **Chart set list and chart list** (`api.charts`). Either two lists or one combined carousel like osu! or the default UI. Rows are asked by index and can be not loaded yet; never copy the list.
2. **Metadata:** difficulty, duration, gamemode/keymode, and anything else the chart exposes.
3. **Search, sorting, filters, collections** (`api.charts`).
4. **Modifiers and mutators** (`api.play`: rate, toggles, `addMutator`).
5. **Chart background** (`api.media:getBackgroundImages()`, event `"background_changed"`).
6. **Chart preview** (`api.media`: audio preview, notes preview).

## Gameplay

The screen only has to draw the gameplay skin: `api.gameplay:drawPlayfield(width, height, transform)`. Skins already draw their own HUD (score, accuracy, combo), so do not redraw those. Forward input with `api.gameplay:receive(event)` and call `api.gameplay:update(dt)` as documented in `rizu/api/Gameplay.lua`. Optional:

- **Pause overlay** driven by `api.gameplay:getState()` / `getStateProgress()`, with `pause`, `resume`, `retry`.
- **Scroll speed / local offset overlay** (`getScrollSpeedText`, `getLocalOffset`).
- Leaving the play: `finish()` / `close()`; see the file for which one when.

## Result

Everything is optional (`api.result`, read when the screen is entered):

1. **Accuracy** (and maybe score).
2. **Title, artist, chart name.**
3. **Judges** and other score info.
4. **Metadata**, difficulty and gamemode/keymode.
5. **Hit graph.**
6. **Chart background.**

Offer at least: back to select, retry.

## Extra features

The default UI has many more elements (DLC, multiplayer, editor, command palette, skin editor, ...). They exist there to please everyone. Do not add them to a custom UI unless the user asks for them.

## Performance rules

- **Gameplay screen:** no per-frame table or string allocation, no layout passes, no new fonts/canvases/shaders, no work except the draw call and input. Preload everything in `load()` or on entering the screen. Draw nothing heavy over the playfield.
- **Other screens:** expensive layout, shaders and blur are fine. Still avoid rebuilding static things every frame; cache what only changes on events (`api.<area>:on("...")`).
- Do not keep chart/score/mutator tables from the API past the frame unless the docs say so.

## Workflow for an agent

1. Read `creating-rizu-plugins`, `rizu/api/README.md` and the default UI in `ui/` (the reference for API usage).
2. Pick the UI library and the drawing approach; write them down.
3. Build in this order: settings escape → song select (list + select) → gameplay → result → extras.
4. Run with `./ui-preview <module>` after each step. Then test in the real game for gameplay.
5. Keep game-specific hacks (`self.game`) in one clearly marked place.
