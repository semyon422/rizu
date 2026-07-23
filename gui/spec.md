# GUI Library Spec

A retained-mode UI library for LÖVE. One node type — `View` — forms a tree per screen. Per-frame work runs over flat cached arrays; layout runs only when the tree changes or the window resizes.

## 1. Core principles

- **One type.** Views parent Views. A *container* is a View with children (usually plus an arrange strategy). A *leaf* is a View without children.
- **Two write channels, strictly separated.** The *layout channel* (anchors, offsets, strategies → resolved rect) is owned by the layout system. The *visual channel* (offset transform, pivot, rotation, scale, opacity) is owned by you and by animations. Neither ever writes the other's state — with exactly one documented exception, the layout-transition compensation (§11.4).
- **Three kinds of layout data, never mixed.** *Authored inputs* (anchors/offsets — yours), *transient arranged output* (the current strategy pass's rects — cleared and rewritten every pass), and the *resolved rect* (`x/y/width/height` — layout's output, read-only to everyone else).
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

The *authored size* of a view is `offset_max - offset_min`. It is what self-sizing views update (§13.1) and what strategies read as a child's desired size (§5.2).

**Transient arranged output** — written by the parent's strategy, cleared every pass:

| Field | Meaning |
|---|---|
| `arranged` | `{x, y, w, h}` in parent content space, or nil. Written only by strategies during `arrange`; cleared by the container before each pass (§5). When present, resolution uses it directly and ignores anchors |

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

| Field | Meaning |
|---|---|
| `layout_ignore` | The parent's strategy skips this child |
| `align_self` | nil or `"fill" \| "start" \| "center" \| "end"` — overrides the strategy's alignment for this child (§5.2) |
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

- **Logical units**: everything in a tree — anchors, offsets, resolved rects, strategy math.
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

`opacity` inherits multiplicatively: `effective_opacity = parent.effective_opacity * self.opacity`, composed during flatten and §4.4 walks. The draw loop applies it (§7.5): `love.graphics.setColor(1, 1, 1, effective_opacity)` before `v:draw()`. Views that set their own colors must preserve inherited alpha through the provided helper (`View:color(r, g, b, a)` multiplies `a` by `effective_opacity`) — a view that hardcodes its alpha opts out of inheritance. This is a documented limitation of drawing without per-subtree canvases, and it is the entire contract.

## 5. Containers and arrange strategies

A strategy is a config object attached to a container View, invoked during the container's resolve step — after the container's own rect is known, before its children resolve.

```lua
---@class gui.ArrangeStrategy   (contract / duck type)
---@field arrange fun(self, container: gui.View)
---@field contentSize fun(self, container: gui.View): number, number  -- intrinsic content size (§13.2)
```

**The transient-output contract:**

1. At the start of a container's resolve step, every child's `arranged` is cleared.
2. If the container has a strategy, `strategy:arrange(container)` runs and writes `child.arranged = {x, y, w, h}` (parent content space) for each non-`layout_ignore` child.
3. Children resolve: `arranged` if present, anchors otherwise (§3.1).

A strategy never writes authored state. Consequences: repeated relayouts are idempotent; detaching a strategy, reparenting, or toggling `layout_ignore` cleanly returns the child to its authored anchors on the next pass. On axes the strategy manages, the strategy wins over anchors.

A container **without** a strategy places children purely by their own anchors — fully manual layout.

### 5.1 Provided strategies

| Strategy | Config | Behavior |
|---|---|---|
| `Stack` | `padding`, `align_items_x`, `align_items_y` (default `"fill"`) | Every child gets the padded inner rect, or its desired size aligned within it |
| `Flex` | `direction`, `gap`, `justify`, `padding`, `sizes`, `align_items` (cross axis, default `"fill"`) | Distributes the main axis per `sizes` (number = px, `"NN%"` = percent of inner main size, `"content"` = child's authored size, `"*"` = share of remaining space); cross axis per §5.2 |
| `Flow` | `direction`, `gap`, `align`, `padding` | Places children in a line at their authored sizes, cross-aligned by `align` ∈ [0, 1] |

All strategies additionally accept `layout_transition = {duration, easing}` (§11.4): when set, children *glide* to new arranged rects instead of snapping. nil (or `duration = 0`) means snap — the default.

Validation is fail-fast: unknown `direction`/`justify`/`align` values, negative gap or padding, and invalid `sizes` entries are errors. `sizes` shorter than the child list pads with `"*"`. A `"content"` entry uses the child's authored size (`offset_max - offset_min`) on the main axis. Percentages over 100 and fixed/content totals larger than the container are legal: stars then get 0 and items overflow (subject to `clip`). Multiple `"*"` share remaining space equally.

A managed child whose **anchors** express placement intent on a managed axis (anything other than the default point anchor `{0,0}→{0,0}`) is a fail-fast error at arrange time — the strategy would silently override that intent, and silent override is how layout bugs hide. The child's authored *size* via offsets is always legal: it is the strategy's input (§5.2).

### 5.2 Alignment and desired size (intrinsic content within a slot)

Strategies do not have to stretch children. The container's `align_items` sets the default per axis; a child's `align_self` overrides it:

- `"fill"` — the arranged rect covers the slot on that axis (stretch).
- `"start" | "center" | "end"` — the arranged rect is the child's **desired size** (`offset_max - offset_min`, its authored size) placed at the start/center/end of the slot on that axis. Desired size 0 with a non-fill alignment is a developer error (fail fast).

Canonical recipes:

```lua
-- Fixed-size button centered in a full-screen Stack
local stack = Stack{ align_items_x = "center", align_items_y = "center" }
button:setSize(200, 50)

-- Intrinsic-height label vertically centered in a Flex row
local row = Flex{ direction = "row", align_items = "center" }
-- (label sized itself via setText, §13.1)

-- Stretched background behind both: a sibling with anchorFill(),
-- or the same container drawn in its own draw()
```

Centering a fixed-size view is preferably done with a centering Stack (survives size changes for free) or `setAlignment` (§2.2 — now also survives size changes). Never by hand-computed signed offsets; that arithmetic does not track size changes.

### 5.3 Padding convention

Everywhere in the library, padding and margin tuples are `{left, top, right, bottom}`. A number is shorthand for all four sides. One convention, no exceptions.

## 6. Layout and flattening

### 6.1 The passes

The internal rebuild (`relayout()`) runs, in order:

1. **Resolve** (top-down): resolve own rect from the parent (§3.1) → clear children's `arranged` → run strategy if present → recurse.
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
| Attaching/detaching `arrange_strategy`, changing `layout_ignore` or `clip` | automatic (assign through setters) |
| Strategy config mutation | config fields are private; mutate via strategy setters, which invalidate |
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
        love.graphics.setColor(1, 1, 1, v.effective_opacity)
        v:draw()                 -- local space: [0, width] × [0, height]
    end
end
love.graphics.setScissor()
love.graphics.setColor(1, 1, 1, 1)
love.graphics.origin()
```

No `push("all")`, anywhere in the hot loop. Because `world_transform` is absolute and applied with `replaceTransform`, the transform stack never accumulates and full state save/restore per view is wasted work. The scissor works in drawable pixels, exactly the space `world_transform` produces (§3.4). Immediate-mode drawing inside `draw()` is fine and expected.

**The graphics-state contract:** a `draw()` that changes shader, canvas, blend mode, line style, font, color, scissor, or transform must restore what it changed before returning. Leaking GPU state is a bug in the view — debug builds may assert it (snapshot after the loop's setup, compare after `draw()`), release builds trust it. Views that legitimately need their own scissor (§9.1) set and clear it inside `draw()`; the loop's per-view scissor applies to the next view regardless.

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
└── content  (e.g. a Flex column; height authored = total content height)
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

When a container's strategy carries `layout_transition = {duration, easing}` (§5.1), children whose arranged rect changed in this rebuild *glide* instead of snapping:

1. Pass 4 (§6.1) already computes each view's old vs. new resolved rect.
2. **The single documented exception to the two-channel rule** (§1): the transition hook writes `offset_x += old_x - new_x`, `offset_y += old_y - new_y` — the view visually stays where it was. This is the *only* place layout writes the visual channel.
3. A registry transform tweens `offset_x/offset_y → 0` with the strategy's easing (house default: `OutQuint` ≈ 0.25 s). One recompose per frame, no relayout.
4. Size changes ride the same mechanism: `scale_x = old_w / new_w → 1`, `scale_y = old_h / new_h → 1`, around the view's current pivot. (Known limitation: with a non-origin pivot the compensation is approximate; acceptable for glides.)
5. The **resolved rect is final immediately** — layout, strategies, and `onLayoutChanged` all see the new geometry at once. During the glide, hit-testing follows the *visual* position (it reads `world_transform`), i.e. you click what you see. That is deliberate.

`layout_transition = nil` or `duration = 0` → snap (the default; opt-in per container). Acceptance: resolved rects must be identical with transitions on or off — only the visual channel may differ (§16.11).

### 11.5 Whole-subtree motion

Animate the subtree root's offset; children follow through composition. Subtree **fade** works the same way through inherited `opacity` (§4.6) — and note §2.4: a subtree faded to zero also stops receiving input, for free. Screen transitions (§7.2) are this, applied to a screen root.

**Layout-affecting changes** (reordering a Flex row, resizing a cell): change layout inputs and let invalidation schedule the rebuild. With `layout_transition` on the container, the visual glide comes for free; without it, the change snaps. Never fake layout changes with the visual channel.

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

There is no fit-content layout mode — deliberately. Fit inverts layout's data flow (child → parent), forces "indefinite size" semantics for fill/percent/`"*"` children inside fit containers, and turns relayouts into content-driven events that can cascade to the root. Layout in this library stays one-directional: parent rect → child rect, top-down, done. (Reference implementations of fit confirm the cost: mutual-exclusion rules between fit and relative sizing, axis-filtered invalidation propagation, and padding/margin double-counting hacks. We choose not to pay it.)

The two things fit would have been used for are covered by explicit helpers instead.

### 13.1 Self-sizing views

A view that owns intrinsic content (text, a texture) sizes itself when the content is set:

```lua
function Label:setText(text)
    self.text = text
    self:setSize(self.font:getWidth(text), self.font:getHeight())
end
```

`setSize` rewrites the authored offsets and invalidates (§2.2) — and, when alignment was recorded via `setAlignment` (§2.2), re-derives the offsets first, so a centered label stays centered as its text changes. This *is* fit-content for leaves — no measure pass, no cascades. Note the consequence: a self-sizing child does **not** resize an ancestor that was sized by `contentSize()` — the owning code recomputes explicitly (§13.2).

### 13.2 The `contentSize` strategy helper

A container that should hug its children is sized at build time by the same math a measure pass would run, exposed as a function on the strategy:

```lua
local w, h = flow:contentSize(panel)   -- main-axis sum, cross-axis max, padding, gaps
panel:setSize(w, h)
```

`contentSize` measures **intrinsic inputs only**: authored sizes and self-sized content. Encountering a parent-relative spec (Flex `"*"` or `"%"` on the measured axis, fill anchors on the measured axis) is a fail-fast error — that circularity is exactly what §13 rejects; if you need it, pass an explicit available size to the strategy instead. Call once after building children; call again from whatever code later changes the content.

### 13.3 If fit is ever reconsidered

The constraints that make it expensive, kept as a warning label:

- `measure()` must never read resolved `width`/`height` (feedback loop); the default returns the authored size.
- Fill, percent anchors, and Flex `"*"` inside a fit container are circular — they need a degradation rule (relative parts contribute only their intrinsic part during measure, and apply after the container resolves).
- `measure()` takes no size constraint, so height-for-width content (wrapped text, aspect-fit images) stays unsupported regardless.
- Invalidation needs a short-circuit rule (measured size unchanged → stop propagating), or a deep content change forces a root relayout.
- Measure ignores the visual channel: scale, rotation, offset, and opacity never affect a view's layout footprint.

## 14. Migration from the previous `gui`

- `View.width/height` + `Box` allocation collapse into the resolved rect. Code reading `view.box.x` for screen space moves to `getWorldPosition()`; code reading `box.width` moves to `width`.
- `setPivot()` used for *slot alignment* migrates to `align_self`/`align_items` (§5.2), `setAlignment` (§2.2), or wrapper views; `pivot` remains for rotation/scale origin only.
- `transform` becomes local; anything needing screen space moves to `world_transform` / `getWorldPosition()`.
- `hideView`/`showView` migrate to `visible` (§2.4) or tree attach/detach (modals). Fades migrate to transforms — and note derived presence (§2.4) makes "faded out but still clickable" impossible.
- Size-dependent work moves from `load()` to `onLayoutChanged` (§6.1 pass 4).
- Flex with omitted `sizes`: intrinsic (authored-size) children keep their size; children without one receive `"*"`. Unchanged behavior, now specified.
- Padding tuple order changes from the old `{left, top, bottom, right}` indexing to `{left, top, right, bottom}` — audit every literal.
- The editor keeps its custom coordinate/hit-test paths through the overridable `isMouseOver` contract (§8.1) and an explicit scale policy (its own root scale, not silent inheritance).
- Reuse, don't rewrite: the `gui.input` event classes and their tests (with §8.1's payload naming: text events expose `text`), and the Stack/Flex/Flow algorithm tests — strategies change only to emit transient `arranged` rects. Tests move with their source.
- Animation split: `SpringValue` stays for continuous retargetable motion (§11.3); discrete property animation (fades, slides, hover) moves to the §11.1 transform registry; scroll moves to §9.2 decay dynamics. `TweenValue` survives only where a freeform tween is genuinely the right tool.
- Close/remove call sites migrate from manual "remove on completion" bookkeeping to `expire()` (§11.2).
- Repository conventions: the accepted architecture lands in `gui/spec.md` (starting with `## Goal` and `## User Experience`), with migration notes in the app and editor specs. `Layer` is a base class, `ArrangeStrategy` a duck-typed contract — name them per repo rules (`I` prefix only for true interfaces).

## 15. Appendix: invariants and conventions

1. Padding/margin tuples are always `{left, top, right, bottom}`.
2. Resolved sizes are clamped ≥ 0; edges rounded once, size derived from rounded edges; draw-time snapping handles non-integral `ui_scale`.
3. `size_mode` is explicit. Never infer layout intent from anchor table identity. `setPosition`/`setSize` on a fill axis fail fast.
4. Anchor/offset tables are value objects: assign fresh, never mutate in place, never alias.
5. `x`, `y`, `width`, `height` are read-only outside the layout pass (carve-out: `Screen` owns the root's rect, §7.4).
6. Layout never writes authored state (`anchor_*`, `offset_*`). Strategies write only the transient `arranged` rect, cleared every pass. Relayouts, attach/detach, and reparenting are idempotent.
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
17. Content sizing is explicit: self-sizing views plus intrinsic-only `contentSize()`. There is no fit pass.
18. Zero scale is non-hittable; strategy configs, tree mutations, non-finite geometry, and placement-anchored children inside strategies fail fast with actionable errors.
19. The draw loop never calls `push("all")`; transforms are absolute and applied with `replaceTransform`. A `draw()` must not leak GPU state (shader/canvas/blend/font/color/scissor/transform) — leaking is a bug in the view.
20. Animations step before view `update` code each frame; transforms replace per target; `LatestTransformEndTime` drives `expire()`.
21. Clicks are distance-gated and suppressed once a drag starts; drags have their own start threshold. Text events expose `text`.
22. Transform composition reuses cached `love.Transform` objects; steady-state per-frame work allocates nothing worth measuring.
23. Flatten maintains complete `views` plus method-filtered `update_views`/`draw_views`; filtering compares resolved methods against the base no-op methods and preserves DFS order. Dynamic instance callbacks go through `setUpdate`/`setDraw`, never direct assignment.

## 16. Acceptance suite

1. Repeated relayout, strategy attach/detach, reparenting, and `layout_ignore` toggles preserve authored state and produce identical rects.
2. Odd parent sizes, percent anchors, non-integral `ui_scale`, and adjacent Flex children produce no seams or overlaps.
3. Initial layout, resize, dynamic attach, and detach invoke `load`/`onLayoutChanged`/`unload` exactly once, in the documented order.
4. Removal from input, update, and draw never touches the removed subtree after unload; focus, hover, press, and capture are cleared — including removal mid-drag.
5. Multiple queued pointer/key/text events dispatch once, in poll order, on current geometry, with event-time coordinates.
6. Modal/popup focus is trapped and restored; handled input never reaches a lower blocked layer; `exit()` returning `false` vetoes navigation.
7. Nested clips and ScrollViews stay correct after relayout at nonzero scroll and after translation/scale animations; no cull cause resurrects another.
8. Empty/short/resized scroll content clamps to zero; rubber-band overscroll settles back without input; the scroller sleeps (no cull writes) at rest; virtualized drawing cannot escape its viewport.
9. Cycle, duplicate insertion, removing a non-child, invalid strategy config, non-finite geometry, rotated clip boundary, non-invertible hit tests, placement-anchored children inside strategies, and `setSize`/`setPosition` on fill axes fail with actionable diagnostics.
10. Benchmarks record relayout visits, compose visits, cull checks/writes, and steady-state allocations for representative large trees; `load()`/`flush()` over budget are logged with names.
11. With `layout_transition` enabled, resolved rects are identical to the no-transition run; during a glide, hit tests match the *visual* position; after completion, offsets are exactly zero.
12. Drag/click contract: a release under `DRAG_START_THRESHOLD` produces click; crossing the threshold produces dragstart/drag/dragend and no click; text events carry `text`, key events carry `key`/`is_repeated`.
13. `setAlignment` survives size changes: center-aligned views re-derive offsets on `setSize`/self-sizing and remain centered.

## 17. Implementation-driven additions

The contracts above describe the layout, input, and rendering architecture. During development we occasionally need operations that the architecture does not name but that fall out of it naturally. They live here so they are not confused with the core contract, and so future readers can tell spec-as-designed from spec-as-built.

### 17.1 `View:clear()`

```lua
function View:clear()   -- remove every descendant, keep self attached
```

Recursively detaches the entire subtree rooted at `self`. After the call, `self.children` is empty and no view in the former subtree retains a `parent` reference. `self` itself stays attached to its own parent (use `self.parent:remove(self)` to detach it too).

This is not a new mutation primitive — it is sugar over `remove`, applied depth-first so that descendants lose their children before being detached themselves. It exists because rebuilding a subtree in place (swapping screen content, replacing a list's rows, re-throwing a test harness) is a common operation that would otherwise be either an O(N²) sequence of `remove` calls or a brittle reach into `children`. Being sugar over `remove`, **`clear()` invalidates layout like any other mutation** (§6.2). When lifecycle (§12) lands, `clear` is the natural place to recursively `unload` before detaching, and that behavior will be specified here.
