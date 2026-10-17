# GUI Library Spec

A retained-mode UI library for LÖVE. One node type, `gui.View`, forms a tree per `gui.Screen`. Per-frame work runs over flat cached arrays; layout runs only when the tree or the window changes.

`ui/` is the only consumer. Nothing in `gui/` may require it.

## 1. Principles

- **One node type.** Layout containers, scroll views and composites are `View` subclasses. A plain View with children is the manual-layout container.
- **Two channels.** The *layout channel* (anchors, offsets, container policy → resolved rect) belongs to layout. The *visual channel* (`offset_x/y`, `pivot`, `rotation`, `scale_x/y`, `opacity`) belongs to application code and animations. Layout never writes the visual channel and nothing but layout writes the resolved rect.
- **Three kinds of layout data.** Authored inputs (anchors, offsets, parent-owned track sizes), the transient `arranged` rect a container writes each pass, and the resolved rect `x/y/width/height`.
- **Layout is cold, the frame is flat.** A rebuild happens on tree change, resize or explicit invalidation. `update`, `draw` and input iterate flat arrays built by that rebuild.
- **Animate the visual channel**, never `x/y/width/height`.

## 2. View

### 2.1 State

| Group | Fields | Written by |
|---|---|---|
| Resolved rect | `x`, `y`, `width`, `height` (logical units, parent-relative, size ≥ 0) | layout only; the Screen writes its root's rect |
| Authored layout | `anchor_min`, `anchor_max`, `offset_min`, `offset_max`, `size_mode_x/y` (`"fixed"`/`"fill"`), `align_x/y` | placement setters |
| Arranged | `arranged = {x, y, w, h}` or nil | the parent's `arrange()`, cleared every pass |
| Visual | `offset_x`, `offset_y`, `pivot`, `rotation`, `scale_x`, `scale_y`, `opacity` | setters and transforms |
| Flags | `visible`, `enabled`, `clip`, `layout_ignore` | setters |
| Composed | `world_transform`, `clip_rect`, `effective_visible`, `effective_enabled`, `effective_opacity`, `render_opacity`, `present`, `cull_mask` | compose |
| Flat cache | `flat_index`, `flat_subtree_end` | the Screen's rebuild |
| Tree | `parent`, `children` (order is draw order), `screen` | tree mutation |

Anchor and offset tables are value objects: setters assign fresh tables and never share them between views.

The *authored size* is `offset_max - offset_min`; read it with `getAuthoredSize()`, `getAuthoredWidth()` or `getAuthoredHeight()`. It is what self-sizing views set and what `FlowContainer` and `StackContainer` read as a child's desired size.

`layout_ignore` takes a child out of its container's arrangement; it then resolves from its own anchors like a child of a plain View.

### 2.2 Placement

```lua
view:anchorFixed(x, y, w, h)      -- absolute rect from the parent's origin
view:anchorFill(l, t, r, b)       -- fill the parent with margins
view:anchorPercent(minx, miny, maxx, maxy)
view:fillWidth(l, r)   view:fillHeight(t, b)
view:setAlignment(ax, ay)   view:setAlignmentX(ax)   view:setAlignmentY(ay)
view:setPosition(x, y)            -- fixed axes; position from the parent's origin, drops alignment
view:addPosition(dx, dy)          -- translate, keeps anchors and alignment, works on fill axes
view:setSize(w, h)   view:setWidth(w)   view:setHeight(h)
```

Alignment is recorded, so a later size change keeps the view aligned. `setPosition` resets the anchors to the origin: `setAlignment(0.5, 0.5):setPosition(10, 10)` lands at (10, 10). `setPosition`/`setSize`/`setWidth`/`setHeight` on a fill axis are errors.

Visual setters: `setOffset`, `setRotation`, `setScale`, `setPivot`, `setOpacity`. Flag setters: `setVisible`, `setEnabled`, `setClip`, `setLayoutIgnore`.

Layout setters invalidate layout; visual setters and `setVisible`/`setEnabled` recompose the subtree. **Every setter returns early when the value is unchanged**, so calling them every frame with the same value is free.

### 2.3 Tree mutation

```lua
parent:add(child)             -- append; adding an own child moves it to the end
parent:insert(index, child)
parent:remove(child)
parent:move(child, index)
parent:clear()                -- remove every direct child
```

Adding a view that has a parent removes it from that parent first. Cycles, bad indices and removing a non-child are errors. `clear()` is shallow: each removed child keeps its own subtree, unloads as a unit and can be added again.

### 2.4 Visibility, enabled, presence

| State | Draw | Input | `update(dt)` | Layout space |
|---|---|---|---|---|
| `visible = false` | skipped | skipped | skipped | reserved |
| `enabled = false` | drawn | skipped | runs | reserved |
| not present | skipped | skipped | runs | reserved |

`visible` and `enabled` inherit down the tree as `effective_visible` and `effective_enabled`. A view is *present* unless its `effective_opacity` is ≤ 0.001, its own scale is zero, or its parent is not present; a view faded to nothing stops taking input without anyone hiding it. Toggling these never invalidates layout.

Because visibility and presence are inherited, the renderer and `Screen:acceptInputs` leave a hidden subtree in one jump. Culling (§8.3) is per view and never skips descendants.

## 3. Resolution

Given the parent's size `(pw, ph)`, a view's edges are

```
left   = anchor_min.x * pw + offset_min.x      right  = anchor_max.x * pw + offset_max.x
top    = anchor_min.y * ph + offset_min.y      bottom = anchor_max.y * ph + offset_max.y
```

or the four edges of `arranged` when the parent wrote one. Each edge is rounded once and the size is derived from the rounded edges, so adjacent children never show seams or overlaps. Sizes clamp to ≥ 0.

Everything in a tree is in logical units. `Screen.ui_scale` is baked into the root's transform; the root's rect is `window / ui_scale`. Convert a window point into a view's space with `view.world_transform:inverseTransformPoint`.

## 4. Composition

`compose` builds, per view:

- the local transform: translate to `x + offset_x`, `y + offset_y`, then rotate and scale about `pivot * size`;
- `world_transform = parent.world_transform * local`;
- `clip_rect`: the intersection of every clipping ancestor's world rect, or nil. A clipping view's world transform must be axis-aligned;
- `effective_opacity`, `render_opacity` (opacity relative to the nearest composite boundary, §7.3), effective flags, presence, and the `CULL_CLIP_EMPTY` bit.

A rebuild composes every view. A visual change recomposes only that view's flat range through `composeSubtree()`. A change that touches only opacity, visibility or enabled state uses `composeSubtree(true)`, which keeps matrices and clip rects.

World-space queries: `getWorldPosition()`, `getWorldBounds()`, `isMouseOver(x, y)` (overridable hit shape) and `isPointerOver(x, y)` (hit shape plus the clip rect).

## 5. Layout containers

A container is a View that defines `arrange()`. After its own rect resolves, the layout pass clears every child's `arranged` and calls `arrange()`, which writes `child.arranged` for each child that is not `layout_ignore`. Containers never touch a child's authored state, so reparenting and repeated passes are idempotent. A custom policy is a View subclass with an `arrange()` method.

Padding is a number or `{left, top, right, bottom}` everywhere; containers validate and expand it once when it is set. Shared validation lives in `gui.layout.Layout`. Invalid configuration fails fast. All three containers take child Views in the array part of their config.

| Container | Policy |
|---|---|
| `StackContainer` | Every child gets the padded inner rect. `align_items_x/y` are `fill`/`start`/`center`/`end`; non-fill uses the child's authored size, and a child's own `setAlignment` overrides the container. |
| `TrackContainer` | Splits the main axis into tracks; children fill their track. `add(child, size)` with a number, `"NN%"` (of the inner main size) or `"*"` (equal share of the rest, the default). `setTrackSize(child, size)` changes it. |
| `FlowContainer` | Packs children at their authored sizes along `direction` with `gap`; `align` is a cross-axis factor in [0, 1], or `"baseline"` in a row to line up children that define `getBaseline()`. |

`StackContainer` and `FlowContainer` have `getContentSize()` and `fitContent()`. There is no fit mode: `fitContent()` writes the current content size as the authored size once, and the owning code calls it again when the content changes. Leaves size themselves the same way (`Label:setText` calls `setSize`). `TrackContainer` has no content size because its cross axis and its star and percent tracks depend on the parent.

## 6. Screen

`gui.Screen` owns one tree: `root`, the flat caches, the renderer, the pending-unload queue and the set of animating views.

### 6.1 Rebuild

Layout-affecting calls set `screen.dirty`. `screen:flush()` removes expired views, unloads removed subtrees and, if dirty, rebuilds:

1. **Resolve and compose**, top-down per view: resolve the rect, start a layout transition if one applies (§9.4), compose, call `onLayoutChanged(old_x, old_y, old_w, old_h)` if the rect changed or this is the view's first resolution since it was loaded, then arrange and recurse into the children.
2. **Flatten** in DFS pre-order: `views` (all), `input_views` (override `onHandleInputs`), `update_views` (override `update`), the render command stream, and each view's `flat_index`/`flat_subtree_end`.
3. **`afterLayout()`** on every view that defines it. `ScrollView` uses it to re-clamp and re-cull.

`flush()` clears the flag before rebuilding, so an invalidation made during a rebuild is kept and handled by the next flush. `flush()` runs at the start of `update`, `draw`, `acceptInputs` and `handleInputs`; `resize()` flushes synchronously.

Class-level `update`/`draw` overrides are found automatically. Per-instance callbacks must go through `setUpdate(fn)`/`setDraw(fn)`.

### 6.2 Frame

- `acceptInputs(inputs)`: pointer target collection over `views`, front-most first.
- `handleInputs(inputs)`: `onHandleInputs` on `input_views`, front-most first, then `Screen:onHandleInputs`.
- `update(dt)`: step animations (§9), then `update(dt)` on effectively visible `update_views`. View code always sees this frame's animation state.
- `draw()`: run the renderer.

`gui.UserInterface` owns the shared `Inputs` and the event queue and delegates screen policy to a `gui.IScreenManager`. Events are queued when they arrive and dispatched at the start of the next update, after the manager has flushed and collected targets, so dispatch always sees current geometry.

### 6.3 Lifecycle

- `load()` and `unload()` run once per attach to a loaded screen; constructors do no resource work.
- `remove` marks the subtree `detached` at once (every loop skips it) and queues its unload for the next flush. Adding it back to the same screen before that flush cancels the unload. Moving to another screen unloads, then loads.
- Unloading also resets the view's layout state, so `onLayoutChanged` fires again after a re-attach and nothing glides in. A view may create resources in `onLayoutChanged` and free them in `unload`.

## 7. Rendering

### 7.1 Renderer

The rebuild compiles a packed command stream:

```
DRAW_ITEM, view, next          view overrides draw
BEGIN_COMPOSITE, view, next    opens a CompositeView boundary
END_COMPOSITE
```

`next` is the index after the view's whole subtree. A detached, invisible or absent view jumps there. A culled view is skipped alone.

Each drawn view gets `love.graphics.replaceTransform(world_transform)`, its scissor from `clip_rect`, alpha blending and `Painter.begin(render_opacity)`, then `draw()` in local space `[0, width] × [0, height]`. A `draw()` that changes shader, canvas, blend mode, font, scissor or transform must restore it.

### 7.2 Painter

`gui.Painter` owns color state so inherited opacity cannot be lost: `setColorRgb`, `setColorTable` and `setOpacity` multiply into the opacity the renderer passed to `begin`. Views do not call `love.graphics.setColor` directly.

### 7.3 CompositeView

A `CompositeView` blends its subtree as one layer: descendants' `render_opacity` restarts at the boundary, the content is drawn into a canvas, and the canvas is drawn once with the composite's opacity. The composite's own `draw()` is part of that content.

- The canvas exists only while it is needed. The renderer creates it (sized `rect × ui_scale`, revalidated on every use) when the composite is visible and either translucent or post-processed. It is released when the composite is hidden, unloaded, or opaque again.
- An opaque composite without hooks draws its children straight into the parent target. They are then not cut off at the composite's rect, so a composite whose children overflow should set `clip`.
- A translucent composite with an empty rect draws nothing.
- Subclass hooks: `postProcess(restore_canvas)` runs once the content is finished, `drawUnderlay(opacity)` draws beneath it in local space. Overriding either keeps the canvas at full opacity. `ShadowCompositeView` uses both for a blurred drop shadow.

## 8. Input, clipping, scrolling

### 8.1 Input

`Inputs` is shared by all screens. Target collection calls `inputs:processView(view)` for visible, enabled, present, unculled views that set `handles_mouse_input`; the hit test is `isPointerOver`. Events go to hit views front-most first; a handler returning `true` stops dispatch. A press captures the pointer; a drag starts after `DRAG_START_THRESHOLD` (4 px) on a view with `onDragStart` and suppresses the click. Key and text events go to the focused view, then to views that set `handles_keyboard_input`.

`pushFocusScope(root)`/`popFocusScope(root)` restrict keyboard eligibility to a subtree (modals, popups). When a view is detached or stops being visible, enabled, present or unculled, every `Inputs` reference into its subtree is cleared.

Semantic actions come from `gui.input.ActionMap`; `consumeActionJustPressed` claims an edge for the frame.

### 8.2 Clipping

`clip = true` clips the view's own drawing and its descendants to its rect.

### 8.3 ScrollView and culling

`ScrollView` is a clipping view with one `content` child. Scrolling writes `content`'s visual offset; layout is not involved. State is `(scroll_target, scroll_current)` with frame-rate-independent exponential approach, drag, fling and bounded overscroll; it sleeps at rest. After every rebuild it re-clamps.

`cull_mask` is a bitmask of independent causes: `CULL_CLIP_EMPTY` (set by compose) and `CULL_VIEWPORT` (set by the ScrollView for each content view whose world bounds leave the viewport). Culled views are not drawn and take no input; they still update.

`VirtualizedList` is the alternative for huge lists: one view that computes the visible row range and draws rows itself. Both implement `gui.IScrollModel` for scrollbars.

## 9. Animation

### 9.1 Transforms

A transform tweens one visual target (`offset_x`, `offset_y`, `pivot_x`, `pivot_y`, `rotation`, `scale_x`, `scale_y`, `opacity`) from its current value.

```lua
view:transformTo(target, to, duration, easing, on_complete)
view:fadeTo(a, d, e)   view:fadeIn(d, e)   view:fadeOut(d, e)
view:moveTo(x, y, d, e)   view:moveToX(x, d, e)   view:moveToY(y, d, e)
view:scaleTo(sx, sy, d, e)   view:pivotTo(px, py, d, e)   view:rotateTo(r, d, e)
view:finishTransforms(target?)    -- jump to the end values, run completions
view:clearTransforms(target?)     -- drop without applying or completing
view:hasTransforms()   view:isAnimating()
```

- Starting a transform replaces the running one on that target and drops delayed ones for it. Duration 0 applies at once.
- `on_complete` runs once, after the frame's recomposition.
- The registry lives in `gui.view.Animation`; `View` keeps the public methods.

### 9.2 Delay

`view:delay(d)` returns a chain object with the same animation methods. Calls on it start `d` seconds after everything already scheduled on the view has ended; `:delay()` on the chain pushes later calls further.

```lua
view:fadeIn(0.2):delay(1):fadeOut(0.2)    -- fade in, hold one second, fade out
view:delay(0.5):fadeIn(0.7):moveTo(0, 0, 0.7)
```

A delayed transform leaves the running one on its target alone until its start time and reads its start value then. The view keeps no delay mode: a later call on the view itself starts immediately.

### 9.3 Stepping

A Screen tracks the attached views that have a transform or a layout glide and steps only those, in tree order, at the start of `update`. Each affected subtree is then recomposed once (a view inside an already recomposed subtree is skipped), completions run, and finished views leave the set. Detached views do not step and resume when attached again. `Screen:isTransitionActive()` reads the same set.

`view:expire()` removes the view through the normal `remove` path at the first flush after its last transform ends: `view:fadeOut(0.2):expire()`.

`gui.anim.SpringValue` and `TweenValue` are standalone value animators for code that drives its own state.

### 9.4 Layout transitions

A container with `layout_transition = {duration, easing?, scale_size?}` makes its children glide when it moves them.

- The resolved rect is final at once. The glide is a private compensation on the child (a position delta and a size scale) that `compose` combines with the visual channel and that decays to nothing. `offset_*`, `scale_*` and the transform registry are not involved, so application state and running transforms survive.
- Position glides. Size snaps unless `scale_size = true`, which glides it by scaling the child about its pivot and therefore stretches its content. A child of an ancestor that is already scale-compensating does not scale again.
- A change that arrives mid-glide continues from the current visual rect.
- No glide starts on a view's first resolution after loading, when its parent changed, or when the parent was resized by the window or an ancestor. A container that resizes itself (`setSize`, `fitContent`) still glides its children.
- Hit testing follows the visual position during a glide.

## 10. Invariants

1. Layout never writes authored or visual state; only layout writes resolved rects.
2. `arranged` never survives a pass.
3. Setters are idempotent: an unchanged value does no work.
4. Removal detaches immediately and unloads at the next flush; a detached view is never updated, drawn, stepped or given input.
5. `onLayoutChanged` fires on the first resolution after every load and on every rect change.
6. Animations settle before any `update(dt)`.
7. Hidden subtrees cost one jump in draw and pointer collection; culling is per view.
8. A composite holds a canvas only while it is visible and translucent or post-processed.
9. Padding is `{left, top, right, bottom}`.
