# Skin drawing

Shared rendering infrastructure lives directly under `rizu/skin/`. Every skin format uses it:

- `SkinTextures`: asset lookup in a skin directory and an optional fallback archive, decoding, atlas preparation/upload and resource ownership.
- `SkinAtlas`: the CPU half of `SkinTextures`, plain functions a worker thread runs.
- `SpriteBatch`: ordered, bounded sprite runs. Texture changes and capacity flush a run; sprites are never sorted.
- `TextureImage`: logical dimensions and drawing for standalone images and atlas regions.
- `BitmapFont`: glyph sprites (`<prefix>-0.png` .. `<prefix>-9.png`, `dot`, `comma`, `percent`, `x`...) layout/drawing, independent of game mode.

Mode-specific asset discovery and atlas membership stay in the mode directory (for example, `osu/mania/OsuManiaBatchPlan`). These helpers do not depend on columns, scrolling, or a gameplay engine. They are not a shared gameplay renderer.

## Resource lifecycle

Configure the skin and discover assets, then load graphics, then load views. On skin replacement or unload, unload the views before releasing graphics. Views acquire their images and measure fonts in `load()` and drop references in `unload()`. Drawing never reloads resources or polls an invalidation counter.

`SkinTextures:prepare(assets)` performs CPU work; `upload()` acquires GPU resources. `load(assets)` combines both. Asset `group` names select an atlas, and every atlas holds a white pixel for rectangles (`TextureImage.rectangle`); `"standalone"` explicitly excludes an asset from atlases and SpriteBatches. Grouped lookups before loading return no frames.

## Drawing

```lua
local batch = graphics.batch
batch:begin()
TextureImage.draw(frame, x, y, rotation, sx, sy, ox, oy, batch)
batch:finish()
```

Scopes may nest. No caller should inspect batch state. Outside a scope, atlas draws flush immediately. A font batches its glyphs and flushes before returning, so its caller can safely restore a local transform.

Pass the owning batch when drawing a standalone image among queued sprites: `TextureImage.draw` flushes the preceding run automatically. Flush explicitly **before** changing transform, blend mode, shader, canvas, scissor, or drawing primitives. Finish the outer scope before restoring its transform.

Effects that change blend mode are standalone assets and draw immediately:

```lua
batch:flush()
local mode, alpha = love.graphics.getBlendMode()
love.graphics.setBlendMode("add", "alphamultiply")
TextureImage.drawDirect(effect, x, y)
love.graphics.setBlendMode(mode, alpha)
```

Lighting state belongs to the entire pass, not individual lights. Stage lights draw consecutively under alpha blending; hit lights draw consecutively under additive blending. Set the pass's blend mode only if it differs, restore it once afterward, and do not push/pop graphics state per sprite. This lets LÖVE automatically batch consecutive draws of the same texture/frame. Different animation frames/textures still split automatic batches; no sorting is performed that would change compositing order. Empty/transparent passes do not touch blend state or flush.

`drawDirect` also accepts atlas regions, but never enqueues them. It does not flush for you: flushing after a state change would render earlier sprites with the wrong state.

Standalone LÖVE Images already carry DPI metadata. Atlas regions carry their own logical dimensions and pixel density; `TextureImage` applies that density exactly once. Existing aim/fruits sprite wrappers keep their mode-specific scale conventions; those conventions should not be copied into the shared batch layer.

## HUD elements

HUD elements live in `hud/`. Every skin format uses the same ones; a skin supplies only textures and a default layout.

- `hud/HudElement`: base class. An element declares `fields` (shown in the skin editor and validated on load), returns the textures it needs from `getAssets()`, reads the play through the game api in `update(dt, api)` and draws in local coordinates. All elements have `x`, `y`, `anchor`, `origin` and `scale`.
- `hud/HudElements`: the registry of element types by name. Skins and plugins add types with `HudElements.register(name, Element)`.
- `hud/HudLayout`: a layout is plain data, a list of element values per layer. `"screen"` covers the gameplay viewport, `"conveyor"` the columns of the playfield.
- `hud/Animations`: animation presets per element kind (combo, judgement, rolling numbers). Add another game's animation as a new entry, then pick it by name in the element's `animation` field.
- `hud/HudEditor`: turns the elements' fields into skin editor properties, with add, remove and reset.

A renderer that sets `textures` (a `SkinTextures`) gets a HUD from `PlayfieldRenderer`. Its layout is the one the player saved in the skin config, otherwise `getDefaultHudLayout()`. On load it calls `buildHud()`, loads `getHudAssets()` with its textures (atlas group `"hud"`), then calls `loadHud()`. A renderer with a conveyor layer lists it in `hud_layers` and returns the column area from `getConveyorRect()`.

Text uses sprites only: `BitmapFont` with a glyph prefix. The base skin falls back to the osu! default digits until it ships its own.
