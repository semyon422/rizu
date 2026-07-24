# CompositeView

`CompositeView` renders its children into a canvas and then draws that canvas as one texture. It is useful for screens and modals that animate opacity.

`CompositeView` itself does not paint content. Backgrounds and other content remain ordinary child views.

## What this gives us

- Group opacity for overlapping children
- Shaders applied to an entire subtree
- Masks and clipping applied to the composed texture
- A foundation for other subtree effects

## Architecture

`Screen` continues to own the view tree and its flat `views`, `update_views`, and `draw_views` caches. A separate `Renderer` owns render commands and graphics state.

During relayout, the renderer compiles the tree into a flat command array:

- `BEGIN_COMPOSITE`
- `DRAW_VIEW`
- `END_COMPOSITE`

The compiler must inspect the complete view hierarchy, not only `draw_views`, because a `CompositeView` emits commands even though its own `draw()` is a no-op.

`Renderer:draw()` executes the cached commands every frame. Composite nesting is represented naturally by a render-target stack; a `CompositeView` does not maintain another flat view list.

## Canvas lifecycle

`CompositeView:onLayoutChanged()` creates its canvas after geometry is known. It recreates the canvas only when the required pixel dimensions change and releases the replaced canvas.

`CompositeView:unload()` releases the current canvas. A zero-sized composite has no canvas.

The initial pixel-size policy is:

```text
canvas_width  = ceil(width  * screen.ui_scale)
canvas_height = ceil(height * screen.ui_scale)
```

The renderer maps the canvas back to the composite's logical `width` and `height` when drawing it. Animated transforms scale the existing canvas and do not cause reallocation.

## Redraw policy

Composite canvases are cleared and redrawn every frame. Persistent caching and render invalidation are separate features and are not part of the initial implementation.

## Opacity

The existing `opacity` field and `fadeIn()` / `fadeOut()` API remain unchanged. There is no second public opacity field and `CompositeView` does not override the animation methods.

`effective_opacity` also remains unchanged and continues to propagate through the whole tree. Input collection, derived presence, and other non-rendering behavior depend on it.

Rendering additionally needs a cached internal opacity relative to the active composite boundary, tentatively named `render_opacity`:

- Outside a composite, opacity composes normally.
- A composite is drawn using its `render_opacity`.
- Direct children of a composite begin a new render-opacity chain, excluding that composite's opacity.
- Descendants render into the canvas using that relative opacity.
- Nested composites repeat the same rule.

This renders child overlap at full group strength and applies the composite opacity once when its canvas is drawn. It must not be implemented by dividing by `effective_opacity`, because division fails when an ancestor opacity reaches zero.

## Transforms

Normal `world_transform` propagation remains unchanged because drawing, hit testing, and input all depend on it.

When rendering into a composite canvas, a view uses a transform relative to the active composite:

```text
inverse(active_composite.world_transform) * view.world_transform
```

The renderer then applies the canvas pixel scale required by the canvas dimensions.

When drawing a completed canvas into its parent render target, it uses the composite transform relative to the parent composite. At the top level it uses the composite's normal world transform.

Render-relative transforms are renderer state; they must not replace or mutate a view's cached `world_transform`.

## Drawing and blend modes

Ordinary views draw into the active canvas with normal alpha blending. A completed canvas is drawn into its parent target with premultiplied-alpha blending. Because LÖVE's draw color also uses premultiplied blending here, group opacity must tint all four channels as `{opacity, opacity, opacity, opacity}` rather than `{1, 1, 1, opacity}`:

```lua
-- Render ordinary children into the composite.
love.graphics.setCanvas(canvas)
love.graphics.setBlendMode("alpha")
love.graphics.clear(0, 0, 0, 0)

-- Draw the completed composite into its parent target.
love.graphics.setCanvas(previous_canvas)
love.graphics.setColor(opacity, opacity, opacity, opacity)
love.graphics.setBlendMode("alpha", "premultiplied")
love.graphics.draw(canvas)
```

The renderer restores the previous canvas and blend mode instead of assuming that the destination is always the screen. It also restores the normal graphics-state contract after rendering.

## Nesting

The renderer maintains a stack containing the active canvas and composite boundary. `BEGIN_COMPOSITE` pushes a target and clears it. `END_COMPOSITE` restores the parent target and draws the completed canvas.

This supports nested composites without special traversal or additional view arrays.

## Clipping

Clipping needs renderer ownership. Existing clip rectangles are in screen/drawable coordinates, so a scissor used inside a composite must be converted into the active canvas coordinate space and intersected with the active scissor.

A scissor stack should follow the render-target stack. Full clipping support may follow the initial group-opacity implementation, since the current `Screen` renderer does not yet implement the clipping contract from `gui/spec.md`.

## Shaders

Shader support should be added after basic compositing works. A likely API is:

```lua
composite:setShader(shader) -- nil disables it
```

The shader is applied when `END_COMPOSITE` draws the completed canvas, not while individual children are being rendered. Uniform ownership should be specified separately rather than hidden inside an `enableShader()` method.
