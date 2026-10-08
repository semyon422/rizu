# osu! skin drawing

Shared rendering infrastructure lives directly under `rizu/skin/osu/`:

- `OsuSkinGraphics`: asset lookup, decoding, atlas preparation/upload and resource ownership.
- `OsuSpriteBatch`: ordered, bounded sprite runs. Texture changes and capacity flush a run; sprites are never sorted.
- `OsuImage`: logical dimensions and drawing for standalone images and atlas regions.
- `OsuBitmapFont`: osu! bitmap glyph layout/drawing, independent of game mode.

Mode-specific asset discovery and atlas membership stay in the mode directory (for example, `mania/OsuManiaBatchPlan`). These helpers do not depend on columns, scrolling, or a gameplay engine. They are not a shared gameplay renderer.

## Resource lifecycle

Configure the skin and discover assets, then load graphics, then load views. On skin replacement or unload, unload the views before releasing graphics. Views acquire their images and measure fonts in `load()` and drop references in `unload()`. Drawing never reloads resources or polls an invalidation counter.

`OsuSkinGraphics:prepare(assets)` performs CPU work; `upload()` acquires GPU resources. `load(assets)` combines both. Asset `group` names select an atlas; `"standalone"` explicitly excludes an asset from atlases and SpriteBatches. Grouped lookups before loading return no frames.

## Drawing

```lua
local batch = graphics.batch
batch:begin()
OsuImage.draw(frame, x, y, rotation, sx, sy, ox, oy, batch)
batch:finish()
```

Scopes may nest. No caller should inspect batch state. Outside a scope, atlas draws flush immediately. A font batches its glyphs and flushes before returning, so its caller can safely restore a local transform.

Pass the owning batch when drawing a standalone image among queued sprites: `OsuImage.draw` flushes the preceding run automatically. Flush explicitly **before** changing transform, blend mode, shader, canvas, scissor, or drawing primitives. Finish the outer scope before restoring its transform.

Effects that change blend mode are standalone assets and draw immediately:

```lua
batch:flush()
local mode, alpha = love.graphics.getBlendMode()
love.graphics.setBlendMode("add", "alphamultiply")
OsuImage.drawDirect(effect, x, y)
love.graphics.setBlendMode(mode, alpha)
```

Lighting state belongs to the entire pass, not individual lights. Stage lights draw consecutively under alpha blending; hit lights draw consecutively under additive blending. Set the pass's blend mode only if it differs, restore it once afterward, and do not push/pop graphics state per sprite. This lets LÖVE automatically batch consecutive draws of the same texture/frame. Different animation frames/textures still split automatic batches; no sorting is performed that would change compositing order. Empty/transparent passes do not touch blend state or flush.

`drawDirect` also accepts atlas regions, but never enqueues them. It does not flush for you: flushing after a state change would render earlier sprites with the wrong state.

Standalone LÖVE Images already carry DPI metadata. Atlas regions carry their own logical dimensions and pixel density; `OsuImage` applies that density exactly once. Existing aim/fruits sprite wrappers keep their mode-specific scale conventions; those conventions should not be copied into the shared batch layer.
