# Easy Lua Skins

## Purpose

`rizu.skin.easy_lua` is a small convenience API for writing Lua playfield skins. It supplies reusable VSRG building blocks for common work, while leaving the renderer escape hatch intact: a skin may bypass these classes and draw its entire playfield itself. These classes are not a required base class for skins and do not depend on the legacy `BasePlayfield`.

This is a new system designed from concrete skin experiments, including the legacy skin in `userdata/dlc/skins_rizu/320`. It is not an adapter for that old system. The API should remain easy to extend as those experiments uncover needs.

## Goals

- Make ordinary lane-based playfields concise to define with reusable classes.
- Keep chart/gameplay rules in the engine and rendering policy in the skin.
- Draw engine-provided visible notes directly; do not allocate a UI View or sprite object per chart note.
- Keep textures and their loading separate from the drawing API. A skin may load an image with `love.graphics.newImage()` and pass the resulting `love.Image` to these components.
- Allow a skin author to take full control and draw in a custom `PlayfieldRenderer` instead.
- Support reusable visual components updating over time. `PlayfieldRenderer:update(dt)` is the update hook; it should not become a second source of gameplay time.

## Non-goals for the initial API

- HUD components or a universal HUD layout. HUD design is intentionally deferred.
- A universal playfield base class required by every renderer.
- Texture discovery, caching, fallback resolution, or a new asset registry.
- Sprite batching or per-note retained-mode Views.
- Non-VSRG mode abstractions. Do not assume these column/conveyor concepts describe other modes.

## Coordinate and time contract

- Authored geometry uses a configurable native coordinate space. `Conveyor` defaults to `640 x 480`, but skins may set `width` and `height` for other assets and resolutions.
- The conveyor is fitted by height to the gameplay viewport. Its available native width follows the viewport aspect ratio for the configured native height. At the default `4:3` space that is 640; wider viewports provide more native width. The renderer applies the viewport transform, and the conveyor scales its native height to the viewport height.
- Column positions and element dimensions are authored in this native coordinate space. `pixels_per_second` is also measured in these units per visual-time second.
- Note motion comes from the engine's visual-time deltas (`start_dt`/`end_dt`) and the configured pixels-per-second value. It is derived from gameplay visual time rather than accumulated frame `dt`, so pauses, speed changes, and irregular frame rates do not desynchronize note positions.
- Downscroll moves notes toward the hit position as their visual-time delta approaches zero. Reverse scroll negates the vertical displacement; it does not rotate each note image.
- Sprite origins are centered `(0.5, 0.5)`. Images use their native dimensions and are not fitted to a column's width unless a skin explicitly scales them.

## Initial object model

The initial object composition is deliberately small:

```text
PlayfieldRenderer (game integration / custom-skin boundary)
└── Conveyor
    ├── Sprite (reusable static image component)
    └── Column
        ├── Note style / note renderer
        ├── Receptor
        └── Stage lighting
```

These easy-Lua objects are plain reusable rendering objects, not `gui.View`s. The tree describes composition and update/draw delegation; it does not create a node per gameplay note. `Conveyor:update(dt)` updates its columns and note components, and `Conveyor:draw(...)` receives the engine's visible-note list and asks each column to draw notes for its input.

### Conveyor

Owns an ordered list of columns and the shared vertical scrolling configuration:

- `pixels_per_second`, defaulting to the configured native height (480 by default).
- `width` and `height`, defining the authored native conveyor space; both default to 640 and 480.
- `reverse`, controlling the scroll direction.
- `draw(visible_notes, viewport_width, viewport_height, transform)`, which draws into the viewport using the configured native height.
- `update(dt)`, delegated to reusable child components.

Columns must have unique input identifiers in a conveyor. The conveyor does not decide how gameplay inputs are interpreted or judged.

### Sprite

A reusable static image positioned in native conveyor coordinates. It owns no texture resource; skin code loads and releases the `love.Image`. Configure its center position, scale, rotation, normalized origin, offset, and tint. `draw()` renders it, with optional X/Y overrides for reusable relative placement; `update(dt)` is a no-op extension point for later animated sprites.

### Column

A column explicitly declares:

- `input`: chart input represented by the column.
- `x`: manually authored horizontal centerline.
- `y`: hit position, equivalent to the receptor position to be added later.
- `width`: a suggested lane width only. It is not an implicit hit area and does not force child images to resize.
- `stage_lighting`: optional input-triggered stage flash, separate from hit lighting and the receptor's pressed-state artwork.
- `hit_lighting`: optional short/long note effects; these trigger on successful note judgements, not directly on key presses.

Elements added in future work must be able to set their own X, Y, width, and height relative to or independent of the column. In particular, receptors may need custom dimensions and X offsets, as in IIDX skins.

### Note renderer

A note component iterates the engine's visible-note list and draws matching chart notes immediately. It does not keep a View or sprite instance for each note. The initial style supports:

- An image for short notes, with optional X/Y scale, X/Y offset, and RGBA tint.
- Optional long-note head, body, and tail images.
- Body scaling explicitly selected by the skin: fixed scale by default, or `body_fit_duration` to stretch along the note duration.
- Centered image origins and viewport culling before issuing image draws.

Gameplay note state affects which portions are drawn. For example, an active held long note anchors its head to the hit position; completed heads/tails are no longer drawn. Effects that require a distinct judgement event should be driven by score/judgement information, not inferred from a key press.

## Planned additions and behavior

The 320 skin and API discussion identify likely next components. Add these only when implementing or porting a concrete skin that exercises them:

1. **Stage composition**: assemble a stage from reusable sprites, including static background/side/bottom artwork and layers around the playfield. Preserve a predictable stage draw order relative to column backgrounds, notes, receptors, and stage lighting.
2. **Judgement-driven explosions**: spawn/trigger only on successful score-system hits, with the actual judgement (e.g. Marvelous, Perfect, Good) available for selecting the effect.
3. **Reusable animation**: persistent components may animate through `update(dt)` and be retargeted or restarted by input/judgement events. Do not create retained views per note just to obtain tweens. Any component animation work must preserve the renderer's ownership and lifecycle.

## Integration and lifecycle

`rizu.gameplay.views.PlayfieldRenderer` provides `update(dt)`, `draw(width, height, transform)`, and lifecycle hooks. The gameplay screen calls the selected playfield renderer's update through its existing view update path. A skin that owns a `Conveyor` should update it from its renderer and pass the current engine visible notes when drawing.

Visual note timing remains sourced from the rhythm engine. `dt` is for advancing skin-owned animation state only. A custom renderer may ignore all easy-Lua classes and draw directly using the same renderer contract.

## Resource-loading foundation

`SkinLoadContext` now exposes the CPU-only `SkinResourceContext` helpers:

- `files`: sorted, normalized, skin-relative available files, cached by the registry.
- `getFiles(directory, root_name?)`: filter beneath a directory, preserving root-relative names.
- `resolvePath(path, root_name?)`: resolve a normalized path relative to an explicit asset root.
- `loadImageData(path, root_name?)`: read/decode an image, returning caller-owned `ImageData`.
- `createRequest(assets)`: copy file lists, roots, and explicit asset requests into a plain worker request.

The primary root is named `skin`. Additional roots can be provided when constructing a
resource context. This is not automatic fallback resolution: osu filename matching,
fallback precedence, animation selection, and density remain renderer-specific.
Available files are not automatically decoded.

`SkinResourceLoader` provides the initial pipeline, without progress notifications:

```lua
local Loader = require("rizu.skin.SkinResourceLoader")
local thread = require("thread")

-- Main-thread setup, outside draw().
local request = context:createRequest({
	{name = "note", path = "sprites/note.png"},
	{name = "decoration", path = "sprites/optional.png", optional = true},
})
thread.coro(function()
	local decoded, err = Loader.waitAsync(Loader.startAsync(request))
	if not decoded then
		print(err)
		return
	end
	-- The eventual lifecycle owner must reject stale requests before installation.
	-- For a discarded result, call Loader.releaseDecoded(decoded) instead.
	local resources, upload_error = Loader.install(decoded)
	if not resources then
		print(upload_error)
		return
	end
	-- Borrow resources.assets.note when building components.
	-- Retain resources in the renderer and call Loader.releaseInstalled(resources)
	-- only after its runtime objects have been torn down.
end)()
```

The existing pool executes filesystem reads and `love.image` decoding in a separate
Lua state. The main-thread coroutine resumes when the result arrives; only `install`
creates GPU images. Worker requests must not contain live game/renderer objects or
closures. No image re-encoding is used for transport.

Resolved paths deduplicate decoded/uploaded ownership; logical resource names may
alias one image. Roots with distinct resolved paths remain distinct resources.
Optional failures are recorded in `resources.errors`; required failures release the
partial CPU set. Installation consumes decoded ownership and releases partial GPU
images on failure. Release helpers are idempotent. All pending futures must still be
consumed after cancellation so late decoded data can be released.

### Opt-in renderer lifecycle

`PlayfieldRenderer` now supplies the resource lifecycle without changing legacy
`load()`/`unload()` or caller behavior. A new renderer overrides
`getResourceRequests(context)` to return explicit asset requests. This declaration
runs on the main thread; it must not read or decode assets. The base implementation
returns `nil` for legacy loading. An empty array opts into a texture-free resource set.

```lua
function Renderer:getResourceRequests(context)
	return {{name = "note", path = "sprites/note.png"}}
end

function Renderer:load()
	assert(self:isResourcesReady() and self.resources)
	-- Build runtime components borrowing self.resources.assets.note here.
end
```

Outside draw(), the owner explicitly prepares and then loads runtime objects:

```lua
thread.coro(function()
	local ok, err = renderer:loadResourcesAsync(context)
	if not ok then print(err); return end
	renderer:load()
end)()
```

For a blocking custom UI, `renderer:loadResources(context)` provides the same resource
ownership and readiness without a coroutine or worker; call `renderer:load()` afterward.
The filesystem comes from the registry-provided context. The two immediate-mode examples
in `userdata/pkg/simple_ui/ChartPreview.lua` and `AsyncChartPreview.lua` share a
bind/update/draw/unload API. Simple UI uses async by default and Tab switches modes.

For overlapping loading work, use `startLoadResources(context)` and later
`finishLoadResourcesAsync(ticket)`. Tickets bind their owner and generation.
`unloadResources()` cancels pending generations, and replacement requests supersede
older requests. Every ticket must still be finished exactly once, including cancelled
ones: late CPU data is released without GPU upload. `applyResources(decoded)` is the
lower-level main-thread install operation; it consumes decoded ownership and does not
perform runtime construction. Do not override it with asset IO or partial publication.

`isResourcesReady()` describes resource readiness only. Opt-in renderers must also gate
drawing on their runtime state, and must never initiate loading from draw methods.
Teardown order is `unload()` then `unloadResources()`; runtime teardown alone preserves
textures for rebinding. Neither resource operation dispatches background-HUD lifecycle.
Runtime construction failure is handled by the owner calling both teardown phases.
Installed resources must be torn down before starting a reload.

`rizu/skin/test/ResourceRenderer.lua` is an unregistered example/test fixture that builds
a Sprite from installed images. Tests cover its fake-transport lifecycle, late-result
cleanup, and a real worker/upload/gameplay-draw/preview-draw round trip.

Existing skins remain on the legacy path except the experimental local 320 skin.
Gameplay starts opted-in resource decoding alongside Chart-resource loading and waits
before starting play; Playfield owns runtime/background-HUD teardown, with texture
release afterward. ChartPreviewView prepares opted-in cached renderers once, keeps their
textures across Chart changes, and invalidates pending results on eviction/unload.
The 320 skin no longer loads from draw(), and retry rebuilds its runtime effects/HUD
without redecoding textures. Its assets and descriptors live in ignored userdata;
local integration tests skip those assets when absent in another checkout.
Atlas packing and upload budgeting remain deferred. Decoding uses
LÖVE's supported image formats; FFmpeg fallback is not enabled for skin images yet.


## Design constraints

- Keep all classes under `rizu/skin/easy_lua/`, with LuaLS class annotations matching `rizu.skin.easy_lua.*`.
- Keep construction explicit, validate invalid geometry/configuration, and prefer small constructors/config tables over a large configuration DSL until real usage calls for a factory.
- Do not couple these classes to `ui` or `gui` widgets. They run within gameplay renderer drawing and use Love2D graphics primitives.
- The API is an aid, not a sandbox: custom Lua skin code retains the option to implement different draw order, geometry, animations, or rendering strategies itself.

## Current status

Implemented: `Conveyor`, `Column`, `Sprite`, `Note`, `Receptor`, `StageLighting`, and `HitLighting`; stage lighting is input-triggered while separate short/long hit-light animations respond to successful note states. Both support ordered image frames, configurable frame rate/blend mode, shrink/fade effects, and renderer `update(dt)` integration; tests cover rendering, note-type separation, input-triggered stage lighting, and native geometry.

Not yet implemented: stage composition using `Sprite`, skin discovery/selection changes for a new package format, a sample easy-Lua skin using this namespace, judgement-event delivery, or HUD support.

Treat this document as the direction and scope for the easy-Lua helpers, not as a promise that every planned component already exists.
