# GUI Library Spec

A retained-mode UI library for LÖVE. One node type — `View` — forms a tree per screen. Per-frame work runs over flat cached arrays; layout runs only when the tree changes or the window resizes.

## 1. Core principles

- **One tree type.** Every node is a `View`. Layout containers such as `StackContainer`, `TrackContainer`, and `FlowContainer` are specialized Views, so they compose, animate, draw, and receive input like any other View. A plain View with children is the manual-layout container.
- **Two write channels, strictly separated.** The *layout channel* (anchors, offsets, container policy → resolved rect) is owned by the layout system. The *visual channel* (offset transform, pivot, rotation, scale, opacity) is owned by you and by animations. Neither ever writes the other's state — with exactly one documented exception, the layout-transition compensation (§11.4).
- **Three kinds of layout data, never mixed.** *Authored inputs* (anchors/offsets and parent-owned track metadata), *transient arranged output* (the current container pass's rects — cleared and rewritten every pass), and the *resolved rect* (`x/y/width/height` — layout's output, read-only to everyone else).
- **The hot path is flat.** Flatten builds one complete view array for input/subtree ranges plus filtered update and draw arrays. `update` / `draw` / `acceptInputs` never walk the tree, and layout-only container Views cost nothing in update/draw dispatch. Event-driven work (animation recompose, scroll culling) is bounded to a subtree's flat range and happens only when something actually moved — that's the qualified form of "no tree walks per frame."
- **Layout is cold.** It runs on structural change, window resize, or explicit invalidation — never per frame.
- **Culling is data, not control flow.** Visibility culling is precomputed into per-view flags at the moments geometry changes, and the per-frame loop checks one boolean. (Under a documented containment guarantee, the loop may also skip a whole subtree by index jump, §9.3.)
- **One animation system, everything funnels through it.** Entrances, exits, hovers, layout transitions, and screen transitions are all *transforms* on the visual channel (§11). Feel comes from uniformity plus consistent house defaults, not from per-widget ad-hoc tweens.

## 2. The View

### 2.1 Fields

**Resolved rect** — written only by the layout pass, read-only everywhere else:

| Field | Meaning |
|---|---|
| `x`, `y` | Local position relative to the parent's content origin |
| `width`, `height` | Resolved size, always ≥ 0 |

**Authored layout inputs** — written by you, never by layout:

| Field | Meaning |
|---|---|
| `anchor_min`, `anchor_max` | `{x, y}` points in [0, 1], relative to the parent's resolved size |
| `offset_min`, `offset_max` | Pixel offsets applied to the two anchor points |
| `size_mode_x`, `size_mode_y` | `"fixed"` or `"fill"` — declared intent, used for validation |
| `align_x`, `align_y` | nil, or the alignment factors recorded by `setAlignment` (§2.2). When set, size changes re-derive the offsets so the view stays aligned |

The *authored size* of a view is `offset_max - offset_min`. It is what self-sizing views update (§13.1) and what `FlowContainer` reads as a child's desired size (§5.2).

**Transient arranged output** — written by the parent layout container's internal arrange hook, cleared every pass:

| Field | Meaning |
|---|---|
| `arranged` | `{x, y, w, h}` in parent content space, or nil. Written only by a layout container's internal arrange hook; cleared before each pass (§5). When present, resolution uses it directly and ignores anchors |

**Visual channel** — never read or written by layout (exception: §11.4); free for animation and manual adjustment:

| Field | Meaning |
|---|---|
| `offset_x`, `offset_y` | Pixel offset in parent space — the **offset transform** (§4.3) |
| `pivot` | `{x, y}` in [0, 1], transform origin relative to own size |
| `rotation` | Radians |
| `scale_x`, `scale_y` | Scale factors |
| `opacity` | 0–1, multiplied down the tree (§4.6) |

**Animation state** — owned by the transform system (§11):

| Field | Meaning |
|---|---|
| `transforms` | Per-target registry of running transforms. Private; manipulate only through the §11.1 API |
| `expired` | Set by `view:expire()` — remove this view when its last transform completes (§11.2) |

**Tree:** `parent` (nil on the screen root), `children` (ordered; order = draw order among siblings), `screen` (injected on attach, cleared on detach — the context for invalidation, lifecycle, focus cleanup, and flat-range access; never walk `parent` to find these).

**Behavior/state flags:**

Layout ownership is expressed by the parent type, not by child flags. A child of a layout container is managed by that container; put overlays or independently anchored children in a sibling or nested plain View.

| Field | Meaning |
|---|---|
| `clip` | Descendants are clipped to this view's rect (§9) |
| `visible` | Author-controlled visibility (§2.4). Not culling |
| `enabled` | When false, the subtree is input-inert (§2.4) |
| `detached` | Internal: removed but not yet unloaded (§12). All loops skip it |

**Cached, written by flatten/compose:** `transform` (local `love.Transform`, private), `world_transform`, `clip_rect` (screen-space `{x, y, w, h}` or nil), `cull_mask` (bitmask of independent cull causes, §9.3), `effective_visible`, `effective_enabled`, `effective_opacity`, `flat_index` / `flat_subtree_end` (position and inclusive subtree range in the screen's flat array). Transform composition **reuses** these `love.Transform` objects (`reset`/`apply`); steady-state composition allocates nothing.

**Input state/flags:** `focused`, `mouse_over`, `pressed`, `handles_mouse_input`, `handles_keyboard_input`.

### 2.2 Placement sugar

Convenience setters over anchors/offsets (they store no extra state beyond `align_x/align_y`). **Every one of them calls `invalidateLayout()` automatically** (§6.2):

```lua
function View:anchorFixed(x, y, w, h)        -- point anchor (0,0), absolute rect; clears alignment
function View:anchorFill(l, t, r, b)         -- anchors (0,0)→(1,1), offsets = signed margins; clears alignment
function View:anchorPercent(minx, miny, maxx, maxy)  -- percent rect, offsets zeroed; clears alignment
function View:setAlignment(ax, ay)           -- point anchor (ax,ay); offsets derived from
                                             -- current size, e.g. (0.5, 0.5) = centered.
                                             -- Records align_x/align_y: later setSize and
                                             -- self-sizing (§13.1) re-derive the offsets,
                                             -- so the view stays aligned when its size changes.
function View:setPosition(x, y)              -- fixed mode: moves offsets, preserves size
function View:setSize(w, h)                  -- fixed mode: offset_max = offset_min + (w, h);
                                             -- re-derives offsets first when alignment is recorded
```

`setPosition`/`setSize` are fixed-mode operations: calling either on an axis whose `size_mode` is `"fill"` is a fail-fast error (declared intent contradicted, §15.3).

Visual-channel setters — `setOffset(x, y)`, `setRotation(r)`, `setScale(sx, sy)`, `setPivot(px, py)`, `setOpacity(a)` — recompose the subtree immediately (§4.4) and never invalidate layout. For anything time-based, prefer the transform API (§11.1) over manual per-frame writes.

### 2.3 Tree mutation API

```lua
function View:add(child)               -- append; returns child
function View:insert(index, child)     -- insert at position (z control within siblings)
function View:remove(child)            -- detach (deferred unload, §12)
function View:move(child, index)       -- reorder among siblings
```

Rules, all fail-fast:

- Adding a view that already has a parent removes it from the old parent first (reparenting is remove + add).
- Adding an ancestor of `self` as a child (a cycle) is an error.
- `remove`/`move` with a view that is not a child is an error.
- All four invalidate layout automatically.
- Reparenting across screens is allowed and treated as detach + attach (§12).

### 2.4 Visibility and enabled state

`visible` and `enabled` are author flags, distinct from geometry culling:

| Flag | Draw | Hit-test/input | Update | Layout space |
|---|---|---|---|---|
| `visible = false` | skipped | skipped | **runs** | still reserved |
| `enabled = false` | drawn (dimming is the view's own concern) | skipped (subtree is inert) | runs | reserved |

Both inherit down the tree via `effective_visible` / `effective_enabled`, computed at flatten and refreshed by a flat-range walk when toggled. Toggling them does **not** invalidate layout — it is an O(subtree) flag update, not a rebuild. If an invisible view should not occupy layout space, remove it from the tree instead.

**Derived presence.** Independently of the author flags, a view whose `effective_opacity ≤ PRESENCE_EPSILON` (a small constant, ≈ 0.001) or with a non-invertible transform (zero scale, §3.4) is *not present*: skipped by draw and by hit-test collection, while `update` still runs. This is derived state, not an author flag — a view faded to invisible stops eating input without anyone remembering to set `visible = false`, and fades remain free to animate. Presence is evaluated at compose time and cached alongside the cull bits.

## 3. Coordinates and sizing

### 3.1 Resolution

Given the parent's resolved size `(pw, ph)`:

```lua
if child.arranged then
    x, y, width, height = child.arranged[1], child.arranged[2], child.arranged[3], child.arranged[4]
else
    x      = anchor_min[1] * pw + offset_min[1]
    y      = anchor_min[2] * ph + offset_min[2]
    width  = (anchor_max[1] - anchor_min[1]) * pw + (offset_max[1] - offset_min[1])
    height = (anchor_max[2] - anchor_min[2]) * ph + (offset_max[2] - offset_min[2])
end
width, height = max(0, width), max(0, height)
```

### 3.2 Sizing modes

| Mode | Anchors | Offsets |
|---|---|---|
| `fixed` | `anchor_min == anchor_max` (a point) | Define an absolute rect from that point |
| `fill` | Spread, e.g. `(0,0)→(1,1)` | Signed pixel margins from each edge (`offset_max` typically negative) |

Percent-of-parent sizing needs no dedicated mode — it falls out of anchor spread: anchors `(0,0)→(0.5,1)` with `offset_min = {20, 0}` gives "half the parent's width, 20 px from the left edge." The modes are orthogonal per axis.

### 3.3 Anchor tables are value objects

`anchor_*`/`offset_*` tables are never mutated in place and never shared between fields. Sugar and user code always assign fresh tables. (Lua tables compare by reference — `anchor_min == anchor_max` is never a meaningful test of anything.)

### 3.4 Coordinate spaces and ui_scale

- **Logical units**: everything in a tree — anchors, offsets, resolved rects, and container layout math.
- **Window coordinates**: what LÖVE mouse events arrive in. Logical = window / `ui_scale`.
- **Drawable pixels**: what the scissor and the GPU use. On HiDPI, window ≠ drawable; compute the scissor from `world_transform` (built against drawable space) and never mix the two.
- `ui_scale` is a finite number > 0, owned by the `Screen`, baked into the root's local transform (§7.4). Changing it is a resize: new root size + `invalidateLayout()`.
- A view with `scale_x` or `scale_y` of 0 has a non-invertible transform: it is **not hittable**. Negative scale is legal; hit tests normalize bounds (min/max). World AABBs under rotation are computed from all four corners.
- *(Non-normative, future)*: a `DrawSizePreservingFill`-style container View — fixed virtual canvas scaled into its slot, with named fit strategies (`"fit"` letterbox, `"fill"` crop, `"stretch"`) — may be added for embedded viewports and full-bleed backgrounds. It composes better than root-only `ui_scale` but does not replace it.

### 3.5 Rounding

Resolve produces edges, not independent positions and sizes: compute `left/right/top/bottom`, round **each edge once** (round-to-nearest), then derive `x = left`, `width = right - left`. Two 50% children of a 101-wide parent share the edge at 50.5 → both round it identically → no seam, no overlap. Rounding happens in logical units at resolve time; with non-integral `ui_scale`, logical rounding does not guarantee pixel alignment — draw-time snapping (the role served by a `snapToPixel` painter helper) remains the final step for crisp 1 px lines and text.

## 4. Transforms

### 4.1 Local transform

```lua
transform:setTransformation(
    x + offset_x + pivot[1] * width,
    y + offset_y + pivot[2] * height,
    rotation,
    scale_x, scale_y,
    pivot[1] * width, pivot[2] * height
)
```

### 4.2 World transform

```lua
world_transform:reset()
world_transform:apply(parent.world_transform)   -- root: world = local
world_transform:apply(transform)
```

World transforms are **absolute** (composed from the root down), never relative to external graphics state. Composition reuses the cached `love.Transform` objects — no per-frame allocation. Draw and hit-testing read `world_transform` only.

### 4.3 The offset transform

`offset_x/offset_y` are a layout-independent positional channel, in the spirit of Godot's Control offset transform: because the resolved rect is owned by layout, animations and ad-hoc nudges never touch `x/y` — they write the offset instead. With `pivot`/`rotation`/`scale`/`opacity` (all layout-independent), this covers visual animation without fighting the layout system. Scrolling (§9.2) and layout transitions (§11.4) are the other major consumers.

### 4.4 Recomposition

- The layout pass rebuilds all local/world transforms top-down.
- A visual-channel write recomposes immediately via `View:composeSubtree()`: recompute own local+world from the parent's current world, then descend. **When the view is attached, the descent iterates the flat range `flat_index .. flat_subtree_end`** (flat order is parents-before-children, so composition is valid iteratively — no recursion). The same walk refreshes descendants' `clip_rect`, `effective_opacity`, derived presence (§2.4), and cull bits (§9.1, §9.3), so clip, cull, and presence data can never go stale under animation.
- Animating several visual fields per frame: write fields directly, call `composeSubtree()` once afterward. The transform system (§11.1) batches exactly this way.

### 4.5 World-space queries

```lua
function View:getWorldPosition()
    return self.world_transform:transformPoint(0, 0)
end
```

For scissor rects, effects spawned at a view, and popup anchoring (§10). Convert *into* a tree's local space with `that_tree.root.world_transform:inverseTransformPoint(sx, sy)` — never by assuming the root is pure scale.

### 4.6 Opacity

`opacity` inherits multiplicatively: `effective_opacity = parent.effective_opacity * self.opacity`, composed during flatten and §4.4 walks. The draw loop seeds `gui.Painter` with it (§7.6). Views set RGB and paint-local alpha through Painter rather than calling `love.graphics.setColor` directly, so changing a color cannot accidentally discard inherited opacity. This remains per-view alpha, not group compositing: overlapping descendants are faded independently. True group opacity and subtree shaders require a future explicit compositing container and are outside the v1 contract.

## 5. Layout containers

Layout policy is selected by constructing a layout-container View, not by attaching a strategy object to an arbitrary View. This keeps ownership visible in the tree and lets each container expose only operations meaningful to its policy. Application code does not assign `arrange_strategy`.

A plain View with children remains the manual-layout container: each child resolves from its own anchors and offsets. This is also the stacking primitive—siblings overlap naturally and child order determines draw order.

Layout containers use the same internal transient-output contract as before:

1. After the container's own rect resolves, clear every child's `arranged` value.
2. The container computes and writes `child.arranged = {x, y, w, h}` in its content space.
3. Children resolve from `arranged`; children of a plain View resolve from anchors (§3.1).

`arranged` is never authored state and must not survive a pass. Containers never rewrite a child's anchors or offsets. Repeated relayout and reparenting are therefore idempotent, and moving a child from a layout container to a plain View restores its authored anchor behavior on the next pass.

Internally, a layout container may implement the existing `ArrangeStrategy` duck type and set its private strategy hook to itself. That is an implementation mechanism and extension point, not the application-facing composition API. A custom policy should normally be a `View` subclass that owns its configuration and implements `arrange(self)`; the resolve/flatten/transition machinery does not need to know its concrete type.

### 5.1 `StackContainer`

`StackContainer` places every child in the same padded inner rectangle. It is the standard way to add padding around fill content and to overlap several full-slot children.

```lua
local panel = StackContainer({padding = {16, 12, 16, 12}, background, content})
```

`align_items_x` and `align_items_y` default to `"fill"`. They may be `"fill"`, `"start"`, `"center"`, or `"end"`; non-fill alignment uses each child's authored size on that axis. A child's existing `setAlignment(x, y)` values override the corresponding container axes, so exceptional placement needs no separate `align_self` state. `getContentSize()` returns the largest authored child width and height plus padding, and `fitContent()` applies it as a one-shot authored size (§13.2). Like the other layout containers, it optionally accepts `layout_transition`.

### 5.2 `TrackContainer`

`TrackContainer` partitions one main axis and always fills each child's cross axis.

```lua
local row = TrackContainer({direction = "row", gap = 8, padding = 12})
local sidebar = row:add(View(), 240)
local body = row:add(View(), "*")
local inspector = row:add(View(), "25%")
row:setTrackSize(sidebar, 280)
```

Configuration:

| Field | Contract |
|---|---|
| `direction` | `"row"` or `"column"`; default `"row"` |
| `gap` | Non-negative spacing between adjacent tracks |
| `padding` | A number or `{left, top, right, bottom}` |
| `layout_transition` | Optional `{duration, easing}` (§11.4) |

`add(child, size)` records parent-owned track metadata and returns the child. `size` is a non-negative logical-unit number, `"NN%"`, or `"*"`; omitted size means `"*"`. Fixed and percentage tracks are resolved first, gaps are subtracted, and all star tracks equally share the non-negative remainder. Percentages use the padded inner main-axis size. Oversubscription is legal: star tracks become zero and fixed/percentage tracks overflow. `setTrackSize(child, size)` changes an attached child's track and invalidates layout; removing a child also removes its track metadata.

Track children fill their complete track. Their authored anchors and sizes remain untouched but do not affect their arranged rect. For intrinsic placement or alignment inside a track, add a plain View or `FlowContainer` as the track child and place content inside it. This explicit nesting replaces Flex's combined distribution-and-alignment policy.

### 5.3 `FlowContainer`

`FlowContainer` packs children once, in child order, using each child's authored width and height (`offset_max - offset_min`). It does not distribute unused main-axis space.

```lua
local buttons = FlowContainer({
    direction = "row",
    gap = 8,
    align = 0.5,
    padding = {12, 8, 12, 8},
    ok_button,
    cancel_button,
})
buttons:fitContent()
```

Configuration:

| Field | Contract |
|---|---|
| `direction` | `"row"` or `"column"`; default `"row"` |
| `gap` | Non-negative spacing between adjacent children |
| `align` | Cross-axis factor in `[0, 1]`: 0 = start, 0.5 = center, 1 = end |
| `padding` | A number or `{left, top, right, bottom}` |
| `layout_transition` | Optional `{duration, easing}` (§11.4) |

Every child must have finite, non-negative authored dimensions. In a row, authored width advances the cursor and authored height is aligned in the inner height; a column swaps the axes. Authored anchors are not consulted while the child is managed by the FlowContainer, but remain intact for later reparenting.

`getContentSize()` returns the packed intrinsic size: main-axis sum plus gaps and padding, and maximum cross-axis child size plus padding. `fitContent()` immediately writes that result to the container with `setSize()` and returns the container. It is explicit, one-shot sizing—not a persistent fit mode. If children later change size or membership, owning code calls `fitContent()` again.

Both containers accept Views in the array part of their constructor configuration as normal children, equivalent to adding them in order. A TrackContainer gives such children the default `"*"` track; other sizes are assigned through `add(child, size)` or `setTrackSize`.

### 5.4 Validation and extension rules

Unknown directions, non-finite geometry, negative gaps/padding/sizes, malformed percentages, invalid alignment factors, and track metadata for non-children fail fast. Container configuration that changes layout must eventually be exposed through invalidating setters; direct mutation without invalidation is unsupported.

The two initial containers are intentionally orthogonal and small. More policies can be added as View subclasses without changing authored inputs, transient `arranged` output, resolution, flattening, input, clipping, or animation. In particular, future wrapping flow, grids, scroll containers, or compositing containers must preserve the same tree and transient-output contracts rather than adding another layout channel.

### 5.5 Padding convention

Everywhere in the library, padding and margin tuples are `{left, top, right, bottom}`. A number is shorthand for all four sides. One convention, no exceptions.

## 6. Layout and flattening

### 6.1 The passes

The internal rebuild (`relayout()`) runs, in order:

1. **Resolve** (top-down): resolve own rect from the parent (§3.1) → clear children's `arranged` → let a layout container arrange them, if applicable → recurse.
2. **Compose** (same recursion): rebuild local transforms; `world = parent.world * local`; compose `effective_opacity` and derived presence (§2.4).
3. **Flatten**: DFS pre-order into `screen.views` (skipping `detached` subtrees), computing per view: `clip_rect` (intersection of ancestor clip rects, §9.1), `effective_visible`/`effective_enabled`, static cull bits (empty clip intersection), `flat_index`/`flat_subtree_end`. During the same pass, append views whose resolved `update` method differs from `View.update` to `screen.update_views`, and views whose resolved `draw` method differs from `View.draw` to `screen.draw_views`. Class-level overrides are discovered automatically. Instance-level callbacks must be installed or removed with `view:setUpdate(callback?)` / `view:setDraw(callback?)`; these setters invalidate the flat caches. Direct instance assignment to `update`/`draw` is unsupported because the screen cannot observe it.
4. **Geometry hook**: fire `View:onLayoutChanged(old_x, old_y, old_w, old_h)` for every view whose resolved rect changed — including initial resolution — in flat order (parents before children). This is where size-dependent resources (canvases) and derived geometry live; `load()` must not depend on geometry. Layout transitions (§11.4) hook in here. The same sequence applies to a subtree attached to an already-loaded screen.
5. **Post-flatten recull**: every visible ScrollView re-clamps its scroll state and refreshes viewport cull bits (§9.2, §9.3).

All three arrays preserve DFS pre-order (parents before children, siblings in `children` order). `draw` iterates `draw_views` forward, `update` iterates `update_views` forward, and input traverses the complete `views` array in reverse. Filtering does not change relative ordering.

### 6.2 Invalidation

**Public triggers** (all coalesce into one rebuild per frame):

| Trigger | How |
|---|---|
| Placement sugar (`anchorFixed`, `anchorFill`, `anchorPercent`, `setAlignment`, `setPosition`, `setSize`) | automatic |
| Tree mutation (`add`, `insert`, `remove`, `move`, `clear`) | automatic |
| Layout-container mutation (`add`, `remove`, `setTrackSize`, `fitContent`, future config setters) or changing `clip` | automatic |
| Layout-container config mutation | config fields are private after construction; mutate via container setters, which invalidate |
| `view:invalidate()` | manual escape hatch — content changed in a way that affects layout (§13.1) |
| `view:setUpdate(callback?)` / `view:setDraw(callback?)` | automatic; instance method participation in filtered flat caches changed |
| `screen:resize(w, h)` / `screen:invalidateLayout()` | manual; resize is called by `UserInterface` |

**Mechanics:**

- Every trigger sets `screen.dirty = true` via the view's injected `screen` context. Views not yet attached keep the change locally; attach invalidates anyway.
- `relayout()` (the rebuild) is internal. Public code never calls it directly.
- `screen:flush()`: if `dirty`, clear the flag **first**, then rebuild. Anything invalidated *during* the rebuild (e.g. from `onLayoutChanged`) sets the flag again and is picked up by the next flush — invalidation is never lost, and one frame never rebuilds twice.
- `UserInterface` flushes every active layer before input target collection each frame (§7.3), so new geometry is always active before the next event dispatch.
- Visual-channel writes never invalidate; they recompose (§4.4).

**Forward note (non-normative):** the single `dirty` boolean is the v1 contract. If profiling justifies it, dirty tracking may become per-view bits OR-ed up to the root, letting `relayout()` skip clean subtrees by flat-index jump (a parent size change still dirties its whole subtree — relative-anchored descendants legitimately depend on it). Nothing outside §6 may build against the boolean.

## 7. Screens and the UserInterface

### 7.1 Layer and Screen

`Layer` is a base class (default empty implementations): `load`, `unload`, `update`, `draw`, `acceptInputs`, `receive`.

`Screen` is a `Layer` that owns a view tree: `root`, `views` (complete flat cache), `update_views` and `draw_views` (method-filtered flat caches), `dirty`, `pending_unload` (§12), and `input_handler` (keyboard-adapter view forwarding to `screen:handleKeyDown`).

- `load()` — recursive `view:load()` over the tree, then the first rebuild. Once per screen lifetime.
- `flush()` — run deferred unloads, then rebuild if dirty (§6.2).
- `enter()` / `exit()` — navigation hooks.

### 7.2 Registry and active layers

`UserInterface` holds two separate things:

- **`screen_registry`**: all navigation screens, constructed and loaded once. Inactive screens retain their state (scroll positions, entered text) — they simply don't run.
- **`active_layers`**: the ordered list that actually runs each frame — exactly **one** active navigation screen plus the persistent service layers. Typical stack, bottom → top: active navigation screen, modal layer, overlay layer (§10), notification/tooltip layer, FPS layer.

Navigation replaces the active navigation layer: `exit()` on the old (clearing any input focus inside it), `enter()` on the new. Only active layers are flushed, input-collected, updated, and drawn.

**Blockable exit.** `exit()` may return `false` to veto the navigation ("unsaved changes?") — `UserInterface` then aborts the swap and the outgoing screen stays active. One boolean; no new machinery.

**Screen transitions are transforms.** `enter()`/`exit()` animate the screen root's visual channel (§11) — a whole-screen fade/slide is a subtree transform, free via whole-subtree motion. Exit animations pair naturally with `expire()` for transient layers and popups (§11.2): animate out, removal happens at the last transform's end, through the normal deferred-unload path.

**Heavy screens (non-normative).** If a screen's content is expensive to build, `UserInterface` may keep the outgoing screen active while the incoming one constructs incrementally under a frame budget (§12), calling `enter()` only when the tree is ready — the user sees the old screen's exit crossfade start exactly when the new one can draw.

### 7.3 Frame flow

LÖVE polls events before `update`. To keep dispatch on current geometry, event handling is split into queueing and draining:

1. **Poll phase** — `UserInterface:receive(event, modifiers)` only *enqueues* `{event, modifiers, x, y}` (pointer events keep their event-time coordinates; queue preserves poll order).
2. **UI frame start** (first thing in the UI update):
   a. `inputs:beginFrame(current_mouse_x, current_mouse_y)` — seeds hover context only;
   b. every active layer: `flush()`;
   c. layers **top → bottom**: `acceptInputs(inputs)` — collect hit/focus targets on current geometry;
   d. **drain the queue** in poll order, updating pointer coordinates per event before each dispatch.
3. Every active layer: `update(dt)`. A layer's update **steps its animations first** (transforms §11.1, scroll dynamics §9.2) and only then runs view `update(dt)` code — animation state is always settled before user code reads it. Transform ticks batch their visual-channel writes and recompose once per affected view.
4. Layers **bottom → top**: `draw()`.

Events polled in a frame are dispatched in that same frame's UI phase, against the geometry current after that frame's flush.

### 7.4 Root view and ui_scale

`ui_scale` is a `Screen` property (§3.4). The root's resolved rect is `window_size / ui_scale`; the root's local transform scales by `ui_scale`, so the tree works in logical units and scaling composes into hit-testing automatically. The root's resolved rect is the one rect `Screen` (not the layout pass) writes — the documented carve-out from §2.1's read-only rule.

### 7.5 Drawing

```lua
for i = 1, #self.draw_views do
    local v = self.draw_views[i]
    if not v.detached and v.cull_mask == 0 and v.effective_visible and v.present then
        love.graphics.replaceTransform(v.world_transform)  -- absolute baseline;
        -- world_transform is never composed onto external state,
        -- so no push/pop is needed: each view just replaces
        local r = v.clip_rect
        if r then love.graphics.setScissor(r[1], r[2], r[3], r[4])
        else love.graphics.setScissor() end
        Painter.begin(v.effective_opacity)
        v:draw()                 -- local space: [0, width] × [0, height]
    end
end
love.graphics.setScissor()
love.graphics.setColor(1, 1, 1, 1)
love.graphics.origin()
```

No `push("all")`, anywhere in the hot loop. Because `world_transform` is absolute and applied with `replaceTransform`, the transform stack never accumulates and full state save/restore per view is wasted work. The scissor works in drawable pixels, exactly the space `world_transform` produces (§3.4). Immediate-mode drawing inside `draw()` is fine and expected.

**The graphics-state contract:** a `draw()` that changes shader, canvas, blend mode, line style, font, scissor, or transform must restore what it changed before returning. Color is changed through Painter and is reset by `Painter.begin` for every view. Leaking other GPU state is a bug in the view — debug builds may assert it (snapshot after the loop's setup, compare after `draw()`), release builds trust it. Views that legitimately need their own scissor (§9.1) set and clear it inside `draw()`; the loop's per-view scissor applies to the next view regardless.

### 7.6 Painter

`gui.Painter` owns the small amount of draw-local color state that LÖVE combines in `love.graphics.setColor`. It belongs to `gui`, not to an application UI module.

```lua
Painter.begin(inherited_opacity)       -- called by Screen before every view draw
Painter.setOpacity(local_opacity)      -- default 1 for each view
Painter.setColorRgb(r, g, b)           -- preserves both opacity components
Painter.setColorTable(color)           -- RGB plus optional color alpha
Painter.snapToPixel()
```

The alpha sent to LÖVE is `inherited_opacity * local_opacity * color_alpha`, where omitted color alpha is 1. `setColorRgb` changes only RGB; `setOpacity` changes only paint-local opacity and reapplies the current color. `begin` resets RGB to white and local opacity to 1, preventing one view's Painter state from leaking into the next. Inputs are finite, opacity and color channels are in `[0, 1]`, and invalid values fail fast.

Views normally never pass `effective_opacity` themselves—Screen already supplied it to `begin`. For example, a label uses `setColorTable(self.color)`; a temporary highlight uses `setOpacity(highlight_alpha)` followed by a color setter. Direct `love.graphics.setColor` is unsupported in normal View drawing because it bypasses inherited opacity. Low-level rendering code that must call it is responsible for multiplying Painter's effective alpha and restoring the Painter color contract before returning.

Painter is rendering infrastructure only. It does not affect layout, transforms, presence, hit testing, or the cached `effective_opacity` values.

## 8. Input

Per-view contract: `view:acceptInputs(inputs)` → `inputs:processView(view)`, skipped when `detached`, `cull_mask ~= 0`, not `present`, or not `effective_visible`/`effective_enabled`.

### 8.1 Dispatch contract

- **Collection order is top-most first**: layers top → bottom, flat array in reverse (deepest, front-most first). Because ancestors spatially overlap their descendants, they appear in the hit list naturally — no separate bubbling phase exists or is needed.
- **Dispatch**: an event is offered to hit views in collection order. A handler returning `true` marks it *handled* and stops dispatch. `event:stopPropagation()` stops without claiming handled-ness semantics beyond it. Unhandled pointer events pass through to lower hits and, ultimately, lower layers.
- **Routing**: click qualifies when the release lands within `MOUSE_CLICK_MAX_DISTANCE` of the press **and no drag began**; a pressed view **captures** the pointer (drag events go to it until release, regardless of hover); wheel rides the hit list (a ScrollView ancestor receives what its rows don't handle); key/text go to the focused view, else to `focus_requesters` in collection order.
- **Drag vs. click**: a drag starts only after the pointer moves at least `DRAG_START_THRESHOLD` (≈ 4 px) from the press point. Once a drag has started, the click is suppressed — the release produces `DragEnd` + `MouseUp`, never `MouseClick`. Click dispatches to the *press* target (the release need not be over the same view); this is deliberate, and `MOUSE_CLICK_MAX_DISTANCE` should be small (single-digit px) so sloppy drags don't read as clicks.
- **Event payloads**: key events expose `key` and `is_repeated`; text events expose `text` (never reuse `key` for text); pointer events expose event-time coordinates (§7.3).
- **Hit test**: `world_transform:inverseTransformPoint(mx, my)` inside normalized `[0, width] × [0, height]`, plus the point inside `clip_rect` when present. Non-invertible transform (zero scale) → not hittable (§3.4). `isMouseOver` is overridable per view — the supported extension point for custom shapes and editor hit paths.

### 8.2 Focus scopes

`Inputs` owns a **focus scope stack**. Keyboard eligibility is restricted to views inside the top scope's subtree (and that scope's own `focus_requesters`).

- Opening a modal or popup: `pushFocusScope(modal_root)` — saves the current focus, moves focus into the scope (or clears it), and blocks key/gamepad fall-through to lower layers.
- Closing: `popFocusScope()` — restores the saved focus **only if that view is still attached and visible**.
- The fullscreen backdrop view (below the modal/popup in child order, `handles_mouse_input = true`, handlers return `true`) is the mouse half of the same contract.

### 8.3 State cleanup

When a view is detached, or becomes invisible/disabled/culled/not-present, every shared `Inputs` reference into its subtree is cleared: keyboard focus, `mouse_target`, `mouse_over`, `pressed`, the stored mouse-down target, and drag capture. Focus restoration on scope pop revalidates attachment. This cleanup is load-bearing: a view removed mid-drag must not receive `DragEnd`, and a removed pressed view must not stay `pressed` in a stale snapshot.

## 9. Clipping and scroll views

### 9.1 Clip rects

`view.clip = true` clips the view's descendants to its resolved rect. `clip_rect` is the intersection of all ancestor clip rects in drawable pixels (corner-transformed via `world_transform`). It is refreshed at flatten **and** inside `composeSubtree` walks (§4.4), so translating/scaling a clip view or any ancestor never leaves stale clips.

Rules:

- The clip boundary's world transform must be axis-aligned (translation/scale fine, rotation rejected — fail fast). Rotated *descendants* are fine; their world AABB uses all four corners and is clipped by the axis-aligned boundary.
- The clip view's own drawing is not clipped — only descendants. A view that draws content needing clipping (a virtualized list's imgui rows, §9.4) sets its own scissor from its own `world_transform` at the top of its `draw()` (and clears it before returning, §7.5 contract).

### 9.2 ScrollView = clip + offset transform + decay dynamics

```
ScrollView   (clip = true, handles_mouse_input = true)
└── content  (e.g. a FlowContainer column; height authored explicitly or set by `fitContent()`)
```

- Wheel/drag input reaches the ScrollView through the hit list. Scrolling is a **visual-channel write** — `content:setOffset(0, -scroll_current)`, one `composeSubtree`, no relayout. The viewport's `clip_rect` doesn't move; content transforms do; hit-testing stays correct.
- **State is `(scroll_target, scroll_current)`, not a tween.** Input (wheel ticks, drag, scrollbar) writes `scroll_target`. Each `update(dt)` while awake: `scroll_current = scroll_target + (scroll_current - scroll_target) * math.exp(-decay * dt_ms)` — frame-rate-independent exponential approach with retargeting for free. When `|scroll_target - scroll_current| < SCROLL_EPSILON` the scroller *sleeps*: current snaps to target and no cull refresh runs until the next input — the event-driven principle (§1) is preserved.
- Decay rates differ per cause (wheel ≈ 0.01/ms, fling floatier ≈ 0.0035/ms; named, tunable constants).
- **Rubber-banding**: while dragging past the clamp, only half the overscroll is applied; `scroll_target` may exceed bounds by up to `SCROLL_CLAMP_EXTENSION`, with a stronger decay pulling it back — the elastic edge that makes scrolling feel physical.
- **Fling**: on drag end, fling distance is integrated from measured pointer velocity decayed per frame, added to `scroll_target`. One cheap formula, no physics sim.
- There is no fit mode (§13), so content height is authored by the code building the rows. After relayout, resize, or content replacement: re-clamp both scroll values and refresh culling (§6.1 pass 5).
- Scrollbar: optional child view using drag capture (§8.1), its size/position derived from `scroll_current`.

### 9.3 Viewport culling

Culling is a **bitmask** of independent causes (`cull_mask`): bit `CLIP_EMPTY` (clip intersection empty), bit `VIEWPORT` (outside a ScrollView's viewport), room for more. Effective cull = mask ≠ 0. One cause never clears another's bit.

- **Static**: at flatten, empty clip intersection sets `CLIP_EMPTY`.
- **Dynamic**: after a scroll change (inside the same `composeSubtree` pass), the ScrollView tests **each content-subtree view's own world AABB** against the viewport and sets/clears its `VIEWPORT` bit — per-view tests, no assumption that descendants stay inside their row's rect. Only changed views are written.
- After any relayout, pass 5 (§6.1) re-runs the clamp and the cull refresh, so a rebuild at nonzero scroll is correct.
- Draw and input check `cull_mask == 0`. `update` is never culled.
- Optimization, allowed only under a documented containment guarantee (a container that guarantees its descendants' bounds stay within its own): the flat loop may skip a culled subtree by jumping to `flat_subtree_end + 1` instead of checking each descendant.

### 9.4 Virtualized lists

For huge lists (thousands of rows), don't create row views at all:

- One view with `clip = true`, `handles_mouse_input = true`; its `draw()` **sets its own scissor**, computes the visible row range from `scroll_current`, and immediate-mode draws only those rows.
- Input is manual hit math on that view: inverse-transform event coordinates, `row = floor(local_y / row_height)`. Click, hover highlight, and keyboard navigation live on the list view.
- Scrollbar: imgui-drawn, or one small child view for free drag events.

Rule of thumb: rows-as-views when the count is modest (up to a few hundred) or rows are interactive; imgui rows when the count is huge and rows are simple. A middle point — pooled row views over a virtualized range — is viable when rows are uniform-height and interactive; build it only when a concrete list needs it. All three share §9's clipping, scrolling, and culling machinery.

## 10. Popups and the overlay screen

There is no z-index. Stacking is structural: layers are the coarse z-order, child order within a tree is the fine z-order. Anything floating above its trigger's layer — dropdown items, context menus, submenus, tooltips — lives in the **overlay layer**, not in the trigger's tree (where it would be clipped by the nearest viewport and drawn under later siblings).

### 10.1 Opening a popup (e.g. a dropdown)

1. `local sx, sy = trigger:getWorldPosition()`; use `transformPoint(0, trigger.height)` for the trigger's bottom edge.
2. Convert into overlay space: `overlay.root.world_transform:inverseTransformPoint(sx, sy)` (§4.5 — not a bare division by `ui_scale`).
3. `overlay.root:add(backdrop)` **first** (fullscreen, invisible, closes the popup on press), then `overlay.root:add(popup)` — child order puts the popup above its backdrop; use `insert` for finer control.
4. Place the popup with `anchorFixed(x, y, w, h)` below the trigger; flip above if it would overflow the window's bottom edge.
5. `inputs:pushFocusScope(popup)` (§8.2) — Esc and friends are trapped; backdrop covers mouse.

Submenus are more popups appended to the overlay root — later siblings draw on top. Closing a popup is `popup:fadeOut(0.15):expire()` (§11.2), not an immediate `remove`.

### 10.2 Popups vs. scrolling triggers

- **Close on scroll** (default): the ScrollView broadcasts a scroll event; popups opened from its subtree close. Sidesteps every degenerate state.
- **Follow**: the popup's `update()` re-reads `trigger:getWorldPosition()` and adjusts with `setOffset` — one `transformPoint` per frame, no relayout. Close when the trigger's center leaves the viewport's clip rect.
- **Never** clip a popup to the trigger's viewport.

### 10.3 What lives where

Overlay layer: dropdowns, context menus, submenus, floating tooltips (§8.2's per-frame-position rule applies — move via `setOffset`, never anchors). Above it: notifications, FPS. Below it: the modal layer (a dropdown opened from a modal draws above the modal).

## 11. Animation

**Rule: never animate `x`, `y`, `width`, `height`.** Animate the visual channel: `offset_x`, `offset_y`, `rotation`, `scale_x`, `scale_y`, `pivot`, `opacity`.

### 11.1 The transform registry

Each view owns a per-target registry of running transforms. A *target* names one visual-channel field (`"offset_x"`, `"opacity"`, `"scale_x"`, …). A transform is `{from, to, start, duration, easing, on_complete}`; each tick it writes its field and the view recomposes once (§4.4 batching).

```lua
view:transformTo(target, to, duration, easing, on_complete)  -- from = current value
-- Fluent sugar over the same registry:
view:fadeIn(d, e)   view:fadeOut(d, e)   view:fadeTo(a, d, e)
view:moveTo(ox, oy, d, e)   view:moveToX(ox, d, e)   view:moveToY(oy, d, e)
view:scaleTo(sx, sy, d, e)  view:rotateTo(r, d, e)
view:delay(d)                              -- offsets subsequent transforms' start
view:finishTransforms(target?)             -- jump to end values, fire completions
view:clearTransforms(target?)              -- drop without applying
```

Semantics:

- **Per-target replacement.** Starting a transform on a target removes the running one on that target — no two animations ever fight over a field.
- **Ordering.** Transforms step at the start of the owning layer's `update`, *before* any view's `update(dt)` (§7.3): user code always reads settled animation state.
- **Completion.** Completed transforms are removed automatically; `on_complete` fires exactly once. `LatestTransformEndTime` per view feeds `expire()` (§11.2).
- Durations in seconds. `duration = 0` applies immediately (still through the registry, still replacing).

**House defaults** (named constants — consistent constants across the app are most of "feels really good"):

| Use | Easing | Duration |
|---|---|---|
| Entrance | `OutQuint` (fast attack, gentle settle) | 0.3–0.5 s |
| Exit | `OutQuad` — leaving feels faster than arriving | 0.2–0.3 s |
| Hover/press feedback | `OutQuad` | 0.1 s |
| Layout glide (§11.4) | `OutQuint` | ≈ 0.25 s |

The easing vocabulary is the full standard set (quad/cubic/quart/quint, sine, expo, circ, elastic incl. damped half/quarter variants, back, bounce).

### 11.2 `expire()` — declarative removal

`view:expire()` marks the view to be removed — via the normal `remove` + deferred-unload path (§12) — when its last running transform completes (immediately, at the next flush, if none are running). This replaces the manual "animate first, `remove` on completion" dance everywhere: close animations, popups, notifications, transient layers. `view:fadeOut(0.2):expire()` is the canonical close.

### 11.3 Springs and freeform tweens

The registry is for discrete, time-based animation. Two other tools keep their jobs:

- **`SpringValue`** — continuous, retargetable motion (physics-feel nudges, anything interruptible mid-flight). Springs have no completion; they sleep at epsilon. A spring writing visual fields follows §4.4 batching like everything else.
- **Freeform `tween(dt, fn)`** — acceptable for leaves and one-offs; prefer the registry whenever the target is a named visual field, so replacement/completion/expire semantics apply.
- **Scroll uses neither** — it has its own `(target, current)` + exponential-decay dynamics (§9.2).

### 11.4 Layout transitions

When a layout container carries `layout_transition = {duration, easing}` (§5), children whose arranged rect changed in this rebuild *glide* instead of snapping:

1. Pass 4 (§6.1) already computes each view's old vs. new resolved rect.
2. **The single documented exception to the two-channel rule** (§1): the transition hook writes `offset_x += old_x - new_x`, `offset_y += old_y - new_y` — the view visually stays where it was. This is the *only* place layout writes the visual channel.
3. A registry transform tweens `offset_x/offset_y → 0` with the container's easing (house default: `OutQuint` ≈ 0.25 s). One recompose per frame, no relayout.
4. Size changes ride the same mechanism: `scale_x = old_w / new_w → 1`, `scale_y = old_h / new_h → 1`, around the view's current pivot. (Known limitation: with a non-origin pivot the compensation is approximate; acceptable for glides.)
5. The **resolved rect is final immediately** — layout, strategies, and `onLayoutChanged` all see the new geometry at once. During the glide, hit-testing follows the *visual* position (it reads `world_transform`), i.e. you click what you see. That is deliberate.

`layout_transition = nil` or `duration = 0` → snap (the default; opt-in per container). Acceptance: resolved rects must be identical with transitions on or off — only the visual channel may differ (§16.11).

### 11.5 Whole-subtree motion

Animate the subtree root's offset; children follow through composition. Subtree **fade** works the same way through inherited `opacity` (§4.6) — and note §2.4: a subtree faded to zero also stops receiving input, for free. Screen transitions (§7.2) are this, applied to a screen root.

**Layout-affecting changes** (changing a track size, reordering a FlowContainer child): change layout inputs and let invalidation schedule the rebuild. With `layout_transition` on the container, the visual glide comes for free; without it, the change snaps. Never fake layout changes with the visual channel.

## 12. Lifecycle

- `View:new()` is trivially cheap — table allocation and cached `love.Transform` objects only. **No resource work in constructors.**
- `View:load()` / `View:unload()` — resource setup/teardown, each exactly once per attach. `Screen:load()` runs `load` recursively, once per screen lifetime.
- **Frame budget, self-policed.** `load()` and `flush()` measure themselves; anything over **8 ms** logs a warning naming the view/screen (16 ms is a dropped frame, not a budget). This catches "someone loaded a 4K image in a button" the day it happens.
- **Async means decode, not construction.** LÖVE's GPU object constructors (`newImage`, `newFont`, `newCanvas`, `newShader`) are main-thread only; only *decoding* (`love.image.newImageData`, `love.sound.newSoundData`) may run on a `love.thread`. Cancellation is tied to detach: a decode whose view detached before completion discards its result at the `pending_unload` rendezvous. There is no worker-thread tree building.
- **Incremental construction.** When a screen swap must build many views, build K per frame in `flush()` under a millisecond deadline (a main-thread coroutine), with placeholders occupying layout space via authored size so geometry is stable immediately. Pair with §7.2's deferred `enter()`.
- **Attach** to an already-loaded screen: recursive `load()` immediately; `onLayoutChanged` fires after the subtree's first resolution (§6.1 pass 4). Attach invalidates layout.
- **Detach** (`remove`, including via `expire()`): the subtree is marked `detached` **immediately** — every loop (update, draw, input) skips it from that moment — and queued in `screen.pending_unload`. At the next flush, before rebuilding: clear all `Inputs` references into the subtree (§8.3), run recursive `unload()` exactly once, drop the references. A view removed inside an input/update callback is therefore never updated or drawn after its resources are released, and never stays in a stale snapshot.
- Cross-screen reparenting = detach from one screen + attach to the other (unload then load).
- `Screen:unload()` — recursive `unload`, clears the flat list and pending queue.
- `enter()`/`exit()` — navigation layers only; `exit()` clears focus inside the leaving screen and may veto (§7.2).

## 13. Content sizing without a fit mode

There is no fit-content layout mode — deliberately. Fit inverts layout's data flow (child → parent), forces "indefinite size" semantics for fill/percent anchors and `"*"` tracks inside fit containers, and turns relayouts into content-driven events that can cascade to the root. Layout in this library stays one-directional: parent rect → child rect, top-down, done. (Reference implementations of fit confirm the cost: mutual-exclusion rules between fit and relative sizing, axis-filtered invalidation propagation, and padding/margin double-counting hacks. We choose not to pay it.)

The two things fit would have been used for are covered by explicit helpers instead.

### 13.1 Self-sizing views

A view that owns intrinsic content (text, a texture) sizes itself when the content is set:

```lua
function Label:setText(text)
    self.text = text
    self:setSize(self.font:getWidth(text), self.font:getHeight())
end
```

`setSize` rewrites the authored offsets and invalidates (§2.2) — and, when alignment was recorded via `setAlignment` (§2.2), re-derives the offsets first, so a centered label stays centered as its text changes. This *is* fit-content for leaves — no measure pass, no cascades. Note the consequence: a self-sizing child does **not** resize an ancestor previously sized by `fitContent()` — the owning code invokes that helper again explicitly (§13.2).

### 13.2 Explicit container fitting

A `FlowContainer` or `StackContainer` can hug its children at build time using the same packing math as arrangement:

```lua
local panel = FlowContainer({direction = "column", gap = 8, label, buttons})
panel:fitContent()
```

`getContentSize()` reads **intrinsic authored inputs only** and includes gaps and padding. `fitContent()` calls `setSize()` with that result. Neither method installs a dependency on the children: a later text change, insertion, or removal does not resize the container automatically. The owning code calls `fitContent()` again at the point where it changes that content.

This helper remains compatible with the one-directional layout pass because it runs outside that pass and writes ordinary authored size. A future container may provide an equivalent helper when its content size is well-defined. `TrackContainer` generally cannot infer both axes: numeric tracks determine its main-axis extent, but its fill cross axis has no intrinsic size; star and percentage tracks are parent-relative and cannot be measured without an explicit available size.

### 13.3 If fit is ever reconsidered

The constraints that make it expensive, kept as a warning label:

- `measure()` must never read resolved `width`/`height` (feedback loop); the default returns the authored size.
- Fill/percent anchors and TrackContainer `"*"`/percentage tracks inside an automatic fit container are circular — they need a degradation rule (relative parts contribute only their intrinsic part during measure, and apply after the container resolves).
- `measure()` takes no size constraint, so height-for-width content (wrapped text, aspect-fit images) stays unsupported regardless.
- Invalidation needs a short-circuit rule (measured size unchanged → stop propagating), or a deep content change forces a root relayout.
- Measure ignores the visual channel: scale, rotation, offset, and opacity never affect a view's layout footprint.

## 14. Migration from the previous `gui`

- `View.width/height` + `Box` allocation collapse into the resolved rect. Code reading `view.box.x` for screen space moves to `getWorldPosition()`; code reading `box.width` moves to `width`.
- `setPivot()` used for *slot alignment* migrates to `StackContainer` alignment, `FlowContainer.align`, `setAlignment` (§2.2), or an explicitly nested wrapper View; `pivot` remains for rotation/scale origin only.
- `transform` becomes local; anything needing screen space moves to `world_transform` / `getWorldPosition()`.
- `hideView`/`showView` migrate to `visible` (§2.4) or tree attach/detach (modals). Fades migrate to transforms — and note derived presence (§2.4) makes "faded out but still clickable" impossible.
- Size-dependent work moves from `load()` to `onLayoutChanged` (§6.1 pass 4).
- `Flex`/`Stack`/`Flow` strategy composition migrates to layout-container Views. Use `StackContainer` for padded stacking/alignment, `TrackContainer:add(child, size)` for fixed/percentage/star partitioning, and `FlowContainer` for authored-size packing. Flex's `"content"` track becomes a numeric size supplied by the owning code or a nested fitted container.
- Padding tuple order changes from the old `{left, top, bottom, right}` indexing to `{left, top, right, bottom}` — audit every literal.
- The editor keeps its custom coordinate/hit-test paths through the overridable `isMouseOver` contract (§8.1) and an explicit scale policy (its own root scale, not silent inheritance).
- Reuse, don't rewrite: the `gui.input` event classes and their tests (with §8.1's payload naming: text events expose `text`). Layout algorithm coverage moves to `TrackContainer` and `FlowContainer`; obsolete strategy tests must be migrated rather than left requiring removed modules.
- Animation split: `SpringValue` stays for continuous retargetable motion (§11.3); discrete property animation (fades, slides, hover) moves to the §11.1 transform registry; scroll moves to §9.2 decay dynamics. `TweenValue` survives only where a freeform tween is genuinely the right tool.
- Close/remove call sites migrate from manual "remove on completion" bookkeeping to `expire()` (§11.2).
- Repository conventions: the accepted architecture lands in `gui/spec.md`, with migration notes in the app and editor specs. `Layer` is a base class; `ArrangeStrategy` remains an internal duck-typed layout hook, while public policies are named `*Container` View subclasses. Use the `I` prefix only for true interfaces.

## 15. Appendix: invariants and conventions

1. Padding/margin tuples are always `{left, top, right, bottom}`.
2. Resolved sizes are clamped ≥ 0; edges rounded once, size derived from rounded edges; draw-time snapping handles non-integral `ui_scale`.
3. `size_mode` is explicit. Never infer layout intent from anchor table identity. `setPosition`/`setSize` on a fill axis fail fast.
4. Anchor/offset tables are value objects: assign fresh, never mutate in place, never alias.
5. `x`, `y`, `width`, `height` are read-only outside the layout pass (carve-out: `Screen` owns the root's rect, §7.4).
6. Layout never writes a child's authored state (`anchor_*`, `offset_*`). Layout containers write only parent-owned metadata and the transient `arranged` rect, which is cleared every pass. Relayouts, attach/detach, and reparenting are idempotent.
7. `load` ≠ `relayout`; geometry-dependent work lives in `onLayoutChanged`. Constructors do no resource work.
8. Every layout-affecting public setter invalidates automatically; `relayout()` is internal; invalidation during a flush is not lost.
9. Flushes run before input collection; events are queued at poll time and drained after collection, in poll order, with event-time coordinates.
10. Input traverses top-most layer first, front-most view first; draw traverses bottom-most first.
11. One shared `Inputs`; focus scopes trap modal/popup keys; detach clears **all** input references into the subtree.
12. Animate the visual channel, never the resolved rect. The only layout→visual write in the library is the layout-transition compensation (§11.4).
13. Culling skips draw and input only — never `update`; cull causes are independent bits; author `visible`/`enabled` are separate from culling; derived presence (opacity ≈ 0, zero scale) skips draw and input but not update.
14. Clip boundaries are axis-aligned (rotation on a clip view is an error); rotated descendants are clipped fine via four-corner AABBs.
15. Scrolling is a visual-channel write with `(target, current)` exp-decay dynamics; the scroller sleeps at epsilon; scroll clamps and culling refresh after every relayout, resize, or content replacement.
16. Popups live in the overlay layer, positioned via `getWorldPosition` + inverse root transform; backdrop inserted before the popup; default close-on-scroll; never clip a popup to a viewport.
17. Content sizing is explicit: self-sizing views plus one-shot helpers such as `FlowContainer:fitContent()`. There is no fit pass or persistent child-to-parent dependency.
18. Zero scale is non-hittable; container configs, track metadata, tree mutations, and non-finite geometry fail fast with actionable errors.
19. The draw loop never calls `push("all")`; transforms are absolute and applied with `replaceTransform`. `gui.Painter` resets color state for each view; a `draw()` must not leak shader/canvas/blend/font/scissor/transform state.
20. Animations step before view `update` code each frame; transforms replace per target; `LatestTransformEndTime` drives `expire()`.
21. Clicks are distance-gated and suppressed once a drag starts; drags have their own start threshold. Text events expose `text`.
22. Transform composition reuses cached `love.Transform` objects; steady-state per-frame work allocates nothing worth measuring.
23. Flatten maintains complete `views` plus method-filtered `update_views`/`draw_views`; filtering compares resolved methods against the base no-op methods and preserves DFS order. Dynamic instance callbacks go through `setUpdate`/`setDraw`, never direct assignment.

## 16. Acceptance suite

1. Repeated relayout and reparenting between plain Views, StackContainers, TrackContainers, and FlowContainers preserve authored state and produce identical rects.
2. Odd parent sizes, percent anchors, non-integral `ui_scale`, and adjacent TrackContainer children produce no seams or overlaps.
3. Initial layout, resize, dynamic attach, and detach invoke `load`/`onLayoutChanged`/`unload` exactly once, in the documented order.
4. Removal from input, update, and draw never touches the removed subtree after unload; focus, hover, press, and capture are cleared — including removal mid-drag.
5. Multiple queued pointer/key/text events dispatch once, in poll order, on current geometry, with event-time coordinates.
6. Modal/popup focus is trapped and restored; handled input never reaches a lower blocked layer; `exit()` returning `false` vetoes navigation.
7. Nested clips and ScrollViews stay correct after relayout at nonzero scroll and after translation/scale animations; no cull cause resurrects another.
8. Empty/short/resized scroll content clamps to zero; rubber-band overscroll settles back without input; the scroller sleeps (no cull writes) at rest; virtualized drawing cannot escape its viewport.
9. Cycle, duplicate insertion, removing or sizing a non-child, invalid container config or track size, non-finite geometry, rotated clip boundary, non-invertible hit tests, and `setSize`/`setPosition` on fill axes fail with actionable diagnostics.
10. Benchmarks record relayout visits, compose visits, cull checks/writes, and steady-state allocations for representative large trees; `load()`/`flush()` over budget are logged with names.
11. With `layout_transition` enabled, resolved rects are identical to the no-transition run; during a glide, hit tests match the *visual* position; after completion, offsets are exactly zero.
12. Drag/click contract: a release under `DRAG_START_THRESHOLD` produces click; crossing the threshold produces dragstart/drag/dragend and no click; text events carry `text`, key events carry `key`/`is_repeated`.
13. `setAlignment` survives size changes: center-aligned views re-derive offsets on `setSize`/self-sizing and remain centered.
14. StackContainer applies padding, fill/non-fill alignment, overlap, and one-shot content fitting without altering authored child state.
15. TrackContainer resolves fixed, percentage, and star tracks correctly under padding, gaps, oversubscription, mutation, removal, and odd parent sizes; repeated relayout does not alter authored child state.
16. FlowContainer packs authored child sizes in both directions, aligns the cross axis, and computes gaps/padding consistently between arrangement and `getContentSize`; `fitContent()` is one-shot and preserves recorded alignment.
17. Before each View draw, Painter resets RGB/local opacity and applies inherited opacity. RGB changes preserve alpha, color-table alpha multiplies it, paint-local opacity cannot leak between views, and direct color changes are absent from ordinary View drawing.

## 17. Implementation-driven additions

The contracts above describe the layout, input, and rendering architecture. During development we occasionally need operations that the architecture does not name but that fall out of it naturally. They live here so they are not confused with the core contract, and so future readers can tell spec-as-designed from spec-as-built.

### 17.1 `View:clear()`

```lua
function View:clear()   -- remove every descendant, keep self attached
```

Recursively detaches the entire subtree rooted at `self`. After the call, `self.children` is empty and no view in the former subtree retains a `parent` reference. `self` itself stays attached to its own parent (use `self.parent:remove(self)` to detach it too).

This is not a new mutation primitive — it is sugar over `remove`, applied depth-first so that descendants lose their children before being detached themselves. It exists because rebuilding a subtree in place (swapping screen content, replacing a list's rows, re-throwing a test harness) is a common operation that would otherwise be either an O(N²) sequence of `remove` calls or a brittle reach into `children`. Being sugar over `remove`, **`clear()` invalidates layout like any other mutation** (§6.2). When lifecycle (§12) lands, `clear` is the natural place to recursively `unload` before detaching, and that behavior will be specified here.
