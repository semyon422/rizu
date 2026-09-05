---
name: developing-rizu-ui
description: Use when creating or modifying Rizu screens, views, layouts, controls, sprites, UI animation, or other Lua code built on the gui and ui modules.
---

# Developing Rizu UI

## Overview

Build UI as a retained tree of `gui.View` objects owned by a `gui.Screen`. Keep authored layout and visual animation separate: layout determines `x`, `y`, `width`, and `height`; transforms change presentation without fighting layout.

Read `gui/spec.md` for the full contract and nearby `ui/` code for established patterns.

## View And Screen

Subclass with `local MyView = View + {}` or `local MyScreen = Screen + {}`, and call the base constructor first.

- `View` is the tree node. It owns children, authored layout, resolved geometry, visual transforms, input, and lifecycle hooks.
- Override `load()`/`unload()` for resources, `onLayoutChanged(...)` for size-dependent work, `update(dt)` for behavior, and `draw()` for local-space drawing in `[0, width] x [0, height]`.
- Mutate trees with `add`, `insert`, `move`, and `remove`. Later siblings draw later and receive input first.
- `Screen` owns a root View, rendering, input, layout caches, and animations. Build the tree in `new()`; use `enter()`/`exit()` and `onHandleInputs(inputs)` for navigation and actions.
- Call the base implementation when overriding a method that implements behavior, such as `Screen.update(self, dt)` or `Screen.exit(self)`.

```lua
local Screen = require("gui.Screen")
local TrackContainer = require("gui.layout.TrackContainer")
local FlowContainer = require("gui.layout.FlowContainer")
local Label = require("ui.views.Label")
local Button = require("ui.views.Button")
local UiActions = require("ui.UiActions")

local Example = Screen + {}

function Example:new(ui)
	Screen.new(self)
	self.ui = ui

	local actions = FlowContainer({direction = "row", gap = 12})
	actions:add(Button("Back", function() ui:setScreen(ui.main_menu) end))
	actions:fitContent()

	local page = TrackContainer({direction = "column", gap = 20, padding = 32})
	page:add(Label({font_name = "bold", font_size = 36, text = "Example"}), 48)
	page:add(require("gui.View")(), "*")
	page:add(actions, actions.offset_max[2] - actions.offset_min[2])
	self.root:add(page):anchorFill(0, 0, 0, 0)
end

function Example:enter()
	self.root:setOpacity(0):fadeIn(0.35, "OutQuint")
end

function Example:onHandleInputs(inputs)
	if inputs:consumeActionJustPressed(UiActions.cancel) then
		self.ui:setScreen(self.ui.main_menu)
	end
end

return Example
```

## Layout

Every View has three different kinds of geometry. Do not mix them:

| Geometry | Fields | Owner |
|---|---|---|
| Authored layout | `anchor_min/max`, `offset_min/max`, `size_mode_x/y`, `align_x/y` | Application code and placement setters |
| Arranged layout | `arranged` | Direct parent layout container; temporary and rewritten each pass |
| Resolved rectangle | `x`, `y`, `width`, `height` | Layout pass; read-only to application code |

For a child of a plain View, each resolved edge is `parent_size * anchor + offset`. Equal anchors make a fixed axis; spread anchors make an axis relative to the parent. For example:

```lua
view:anchorFixed(20, 30, 200, 40)       -- absolute rect from the parent's top-left
view:anchorFill(16, 12, 16, 12)         -- fill parent with left/top/right/bottom margins
view:setSize(200, 40):setAlignment(0.5, 0.5) -- fixed size centered in parent
view:anchorPercent(0, 0, 0.5, 1)        -- left half of parent
```

### Placement Setters Are Destructive

Placement calls are state assignments, not independent CSS-like properties. Order matters.

| Setter | What it replaces |
|---|---|
| `anchorFixed(x, y, w, h)` | Both anchors, both offsets, both size modes, and both recorded alignments |
| `anchorFill(l, t, r, b)` | Both anchors and offsets; makes both axes fill and clears alignment |
| `anchorPercent(minx, miny, maxx, maxy)` | Both anchors, zeroes both offsets, derives size modes, and clears alignment |
| `fillWidth(l, r)` / `fillHeight(t, b)` | That axis's anchors and offsets; makes it fill and clears alignment on that axis |
| `setAlignment(ax, ay)` | Both axes' anchors and offsets; makes both fixed and centers the current authored size around the anchor points |
| `setAlignmentX/Y(a)` | That axis's anchors and offsets; makes it fixed and records alignment |
| `setPosition(x, y)` | Both axes' offsets and both recorded alignments; keeps current authored size; fixed axes only |
| `setWidth/Height/Size(...)` | Authored size; fixed axes only. Recorded alignment, if present, is preserved |
| `addPosition(dx, dy)` | Adds to both edge offsets; preserves size and recorded alignment; also works on fill axes |

Consequences:

- `setAlignment(...):setPosition(...)` does not mean "align, then offset". `setPosition` removes the alignment.
- `setPosition(...):setAlignment(...)` does not preserve the position. `setAlignment` rebuilds offsets around the anchor.
- `anchorFill(...):setSize(...)` fails because `setSize` is only valid on fixed axes.
- `anchorPercent(...)` zeroes previous margins. Apply any intended translation afterward with `addPosition`.
- Once alignment is recorded, later `setSize`, `setWidth`, `setHeight`, and self-sizing controls stay aligned.

Safe recipes:

```lua
-- Centered fixed-size content. Either order preserves the final alignment.
view:setSize(320, 64):setAlignment(0.5, 0.5)
view:setAlignment(0.5, 0.5):setSize(320, 64)

-- Centered, then shifted in authored layout while retaining alignment.
view:setSize(320, 64):setAlignment(0.5, 0.5):addPosition(0, 24)

-- Fill with margins, then translate the complete authored rect.
view:anchorFill(16, 12, 16, 12):addPosition(8, 0)

-- Visual-only nudge or animation. Does not change layout or reserved space.
view:setAlignment(0.5, 0.5):setOffset(0, 24)
```

Use `addPosition` when the displacement is part of layout. Use `setOffset`/`moveTo` when it is visual, transient, or animated. Visual offsets affect drawing and hit testing but not sibling placement or content measurement.

### Containers

Choose the smallest suitable layout primitive:

| Tool | Use |
|---|---|
| Plain `View` | Manual anchored children and overlapping layers |
| `StackContainer` | Shared padded slot, fill/aligned content, or overlapping content |
| `TrackContainer` | Rows/columns split into fixed (`240`), percentage (`"25%"`), and equal remainder (`"*"`) tracks |
| `FlowContainer` | Pack children at authored sizes with a gap; no space distribution |

Padding is always `{left, top, right, bottom}`. A container writes each direct child's temporary `arranged` rectangle, so that child's anchors and offsets are retained but ignored while it remains managed by the container.

- `StackContainer` fills every child into one padded slot by default. Non-fill `align_items_x/y` uses authored child size. A child's recorded `setAlignmentX/Y` overrides the Stack alignment on that axis.
- `TrackContainer` owns both position and size of direct children. It always fills the cross axis. Nest a plain View or StackContainer inside a track to align content within it.
- `FlowContainer` uses each child's authored width and height, packs them in order, and uses the container's `align` factor on the cross axis. Child anchors do not position Flow children.
- `setLayoutIgnore(true)` excludes a child from container arrangement and measurement. Its authored anchors then resolve normally, which is useful for an overlay inside a container.
- Moving a child back to a plain View restores its authored anchor behavior because containers never overwrite authored layout.

```lua
local row = TrackContainer({direction = "row", gap = 8, padding = 12})
row:add(sidebar, 240)
row:add(content, "*")
row:add(inspector, "25%")
row:setTrackSize(sidebar, 280)

local badges = FlowContainer({direction = "row", gap = 8, align = 0.5})
badges:add(first_badge:setSize(80, 24))
badges:add(second_badge:setSize(96, 24))
badges:fitContent()
```

### Updating Layout

Layout is cold, not per-frame:

- Placement/tree/container setters and `view:invalidate()` mark the Screen dirty. Changes coalesce and flush before input/update/draw.
- Never write resolved `x`, `y`, `width`, `height`, or transient `arranged`; never call internal `relayout()`.
- `FlowContainer:fitContent()` and `StackContainer:fitContent()` are one-shot. Call them again after child membership or authored child sizes change.
- Self-sizing Views call `setSize()` when content changes. Put size-dependent work in `onLayoutChanged`, not `load()`.
- Use setters such as `setGap`, `setPadding`, `setDirection`, and `setTrackSize`; direct config mutation does not invalidate.
- Visual movement does not need layout. Use transforms or visual setters; they immediately recompose the affected subtree.

## Animation Transforms

Never animate resolved layout geometry. Animate `offset_x`, `offset_y`, `pivot_x`, `pivot_y`, `rotation`, `scale_x`, `scale_y`, or `opacity`.

```lua
view:setPivot(0.5, 0.5)
view:moveTo(0, -12, 0.25, "OutQuint")
view:scaleTo(1.05, 1.05, 0.1, "OutQuad")
view:fadeOut(0.2, "OutQuad"):expire()
```

- General API: `transformTo(target, value, duration, easing, on_complete)`.
- Sugar: `fadeIn`, `fadeOut`, `fadeTo`, `moveTo`, `moveToX/Y`, `scaleTo`, `pivotTo`, and `rotateTo`.
- `delay(d)` schedules subsequent transforms. `finishTransforms(target?)` applies endpoints; `clearTransforms(target?)` cancels.
- A new transform replaces one on the same target. Different targets run together.
- Use `SpringValue` for continuously retargeted motion. Use container `layout_transition = {duration = 0.25, easing = "OutQuint"}` when arranged child rectangles should glide after relayout.
- After several direct visual-field writes, call `composeSubtree()` once.

## Useful gui Classes

| Module | Purpose |
|---|---|
| `gui.Painter` | Color/opacity that preserves inherited View opacity |
| `gui.ScrollView` | Clipped vertical scrolling; explicitly size its content |
| `gui.VirtualizedList` | Very large fixed-height lists |
| `gui.NineSlice` | Resizable nine-slice sprites |
| `gui.Sprite`, `gui.AtlasImage`, `gui.ImageSprite` | Drawable sprite abstractions and atlas regions |
| `gui.SpriteBatch` | Explicit sprite batching for dense repeated drawing |
| `gui.CompositeView` | Canvas-backed subtree with group opacity |
| `gui.anim.SpringValue`, `TweenValue`, `Easing` | Springs, standalone tweens, and easing |
| `gui.input.ActionMap`, `Inputs` | Semantic bindings and consumed action edges |

In `draw()`, use `Painter.setColorTable`/`setColorRgb`. Restore other LÖVE graphics state you change.

## SpriteGenerator

Declare procedural shapes in `ui/SpriteDefinitions.lua`. `ui.Resources.load()` packs them and exposes `Resources.sprites[name]` and `Resources.nine_slices[name]`.

```lua
card = {
	width = 17,
	height = 17,
	border_radius = 7,
	rounding_power = 4,
	slice = 8,
	background_color = Colors.panel,
	stroke = {width = 1, color = Colors.outline},
}
```

Definitions need positive integer dimensions and exactly one of `background_color` or `linear_gradient = {angle = degrees, colors = {start, finish}}`. Colors have 3 or 4 channels in `[0, 1]`; stroke width is a number or side table. `slice` creates nine-slice output and must leave a non-empty center.

Prefer generated sprites/nine-slices for visible rectangles, especially rounded rectangles. Use `Resources.sprites.pixel` scaled to the target size for simple solid rectangles rather than `love.graphics.rectangle`.

## Useful ui Modules

| Module | Use |
|---|---|
| `ui.Resources` | Shared atlas sprites, nine-slices, BMFonts, and cached TTF fonts via `getFont(name, size)` |
| `ui.Colors` / `ui.Color` | Palette and color manipulation helpers |
| `ui.views.Label`, `BMFontLabel` | Self-sizing text |
| `ui.views.Image` | Native-size or fitted `gui.Sprite` |
| `ui.views.Rectangle`, `Panel`, `Line`, `Background` | Common visual surfaces |
| `ui.views.Button` | Basic clickable button |
| `ui.views.form.*` | Forms, controls, and keyboard/gamepad navigation |
| `ui.UiActions` | Semantic UI actions; consume edges instead of testing raw keys |
| `ui.ModalView` / `ui.ModalManager` | Modal contract and ownership |
| `ui.views.PopupContainer` | Floating content that must escape clipping and appear in the overlay |
| `ui.formatters.*` | Presentation formatting for chart, score, replay, and difficulty data |

Keep `ui` as the frontend boundary: `ui` may call game/backend APIs, but `gui`, `rizu`, and other lower-level modules must not import application `ui` classes.

## Common Mistakes

- Animating `x/y/width/height`: animate offsets, scale, rotation, or opacity instead.
- Calling layout every frame: mutate through invalidating APIs and let `Screen:flush()` coalesce work.
- Expecting `visible = false` to remove layout space: remove the View from the tree when space should collapse.
- Putting popups inside clipped content: attach them through the overlay's `PopupContainer`.
- Assigning instance `draw` or `update` directly: use `setDraw(callback)` or `setUpdate(callback)` so flat caches rebuild.
- Drawing with direct color state: use `gui.Painter` so inherited opacity remains correct.
