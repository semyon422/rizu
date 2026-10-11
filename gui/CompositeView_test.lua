local CompositeView = require("gui.CompositeView")
local Screen = require("gui.Screen")
local View = require("gui.View")

local test = {}

-- The test run is headless and LÖVE cannot create or bind canvases without a window.
---@param width number
---@param height number
local function fakeCanvas(width, height)
	return {
		released = false,
		getWidth = function() return width end,
		getHeight = function() return height end,
		getDimensions = function() return width, height end,
		release = function(self) self.released = true end,
	}
end

---@param f fun(t: testing.T)
---@return fun(t: testing.T)
local function withFakeCanvases(f)
	return function(t)
		local lg = love.graphics
		local newCanvas, setCanvas, getCanvas, clear, draw = lg.newCanvas, lg.setCanvas, lg.getCanvas, lg.clear, lg.draw
		---@type any
		local current
		lg.newCanvas = fakeCanvas
		lg.setCanvas = function(canvas) current = canvas end
		lg.getCanvas = function() return current end
		lg.clear = function() end
		lg.draw = function() end
		local ok, err = xpcall(f, debug.traceback, t)
		lg.newCanvas, lg.setCanvas, lg.getCanvas, lg.clear, lg.draw = newCanvas, setCanvas, getCanvas, clear, draw
		assert(ok, err)
	end
end

---@param composite any
---@return any canvas The fake canvas, if the composite holds one
local function canvasOf(composite)
	return composite.canvas
end

---A composite that is translucent, so the renderer has to give it a canvas.
---@param screen gui.Screen
---@param width number
---@param height number
---@return gui.CompositeView
local function addTranslucent(screen, width, height)
	local composite = CompositeView()
	composite:anchorFixed(0, 0, width, height):setOpacity(0.5)
	return screen.root:add(composite)
end

test.canvas_follows_resolved_size_and_ui_scale = withFakeCanvases(function(t)
	local screen = Screen()
	screen:setUIScale(2)
	local composite = addTranslucent(screen, 100, 50)
	screen:resize(800, 600)
	t:eq(canvasOf(composite), nil)

	screen:draw()

	t:eq(canvasOf(composite):getWidth(), 200)
	t:eq(canvasOf(composite):getHeight(), 100)
	t:eq(composite.canvas_scale, 2)
end)

test.resize_replaces_and_releases_canvas = withFakeCanvases(function(t)
	local screen = Screen()
	local composite = addTranslucent(screen, 100, 50)
	screen:resize(800, 600)
	screen:draw()
	local old_canvas = canvasOf(composite)

	composite:setSize(120, 60)
	screen:draw()

	t:eq(old_canvas.released, true)
	t:eq(canvasOf(composite):getWidth(), 120)
end)

test.unload_releases_canvas = withFakeCanvases(function(t)
	local screen = Screen()
	local composite = addTranslucent(screen, 100, 50)
	screen:resize(800, 600)
	screen:load()
	screen:draw()
	local canvas = canvasOf(composite)

	screen:unload()

	t:eq(canvas.released, true)
	t:eq(canvasOf(composite), nil)
end)

test.render_opacity_restarts_inside_composite = withFakeCanvases(function(t)
	local screen = Screen()
	screen.root:setOpacity(0.8)
	local composite = screen.root:add(CompositeView():anchorFixed(0, 0, 100, 50))
	composite:setOpacity(0.5)
	local child = composite:add(View():anchorFill(0, 0, 0, 0))
	child:setOpacity(0.25)
	screen:resize(800, 600)

	t:aeq(composite.effective_opacity, 0.4, 1e-9)
	t:aeq(composite.render_opacity, 0.4, 1e-9)
	t:aeq(child.effective_opacity, 0.1, 1e-9)
	t:aeq(child.render_opacity, 0.25, 1e-9)
end)

test.renderer_draws_nested_composites = withFakeCanvases(function(t)
	local screen = Screen()
	local outer = screen.root:add(CompositeView():anchorFixed(10, 20, 200, 100))
	local inner = outer:add(CompositeView():anchorFixed(20, 10, 100, 50))
	outer:setOpacity(0.5)
	inner:setOpacity(0.5)
	local target
	local child = inner:add(View():anchorFill(0, 0, 0, 0))
	child:setDraw(function()
		target = love.graphics.getCanvas()
	end)
	screen:resize(800, 600)

	screen:draw()

	t:assert(canvasOf(inner) ~= nil)
	t:eq(target, canvasOf(inner))
	t:eq(love.graphics.getCanvas(), nil)
end)

test.reattached_composite_gets_a_canvas_again = withFakeCanvases(function(t)
	local screen = Screen()
	local composite = addTranslucent(screen, 100, 50)
	screen:resize(800, 600)
	screen:load()
	screen:draw()

	screen.root:remove(composite)
	screen:flush()
	t:eq(canvasOf(composite), nil)
	screen.root:add(composite)
	screen:draw()

	t:assert(canvasOf(composite) ~= nil)
end)

test.fixed_size_canvas_follows_ui_scale = withFakeCanvases(function(t)
	local screen = Screen()
	local composite = addTranslucent(screen, 100, 50)
	screen:resize(800, 600)
	screen:draw()
	local old_canvas = canvasOf(composite)

	screen:setUIScale(2)
	screen:draw()

	t:eq(old_canvas.released, true)
	t:eq(canvasOf(composite):getWidth(), 200)
	t:eq(composite.canvas_scale, 2)
end)

test.renderer_skips_composite_without_canvas = withFakeCanvases(function(t)
	local screen = Screen()
	local composite = addTranslucent(screen, 0, 0)
	local draws = 0
	composite:add(View():anchorFixed(0, 0, 10, 10)):setDraw(function() draws = draws + 1 end)
	screen:resize(800, 600)

	screen:draw()

	t:eq(canvasOf(composite), nil)
	t:eq(draws, 0)
end)

test.opaque_composite_draws_directly_and_holds_no_canvas = withFakeCanvases(function(t)
	local screen = Screen()
	local outer = addTranslucent(screen, 200, 100)
	local inner = outer:add(CompositeView():anchorFixed(0, 0, 100, 50))
	local target
	inner:add(View():anchorFill(0, 0, 0, 0)):setDraw(function()
		target = love.graphics.getCanvas()
	end)
	screen:resize(800, 600)

	screen:draw()
	t:eq(canvasOf(inner), nil)
	t:eq(target, canvasOf(outer))

	inner:setOpacity(0.5)
	screen:draw()
	local canvas = canvasOf(inner)
	t:eq(target, canvas)

	inner:setOpacity(1)
	screen:draw()
	t:eq(canvas.released, true)
	t:eq(canvasOf(inner), nil)
	t:eq(target, canvasOf(outer))
end)

test.composite_own_draw_goes_into_its_canvas_at_full_opacity = withFakeCanvases(function(t)
	local screen = Screen()
	local composite = addTranslucent(screen, 100, 50)
	local target, alpha
	composite:setDraw(function()
		target = love.graphics.getCanvas()
		alpha = select(4, love.graphics.getColor())
	end)
	screen:resize(800, 600)

	screen:draw()
	t:eq(target, canvasOf(composite))
	t:eq(alpha, 1)

	composite:setOpacity(1)
	screen:draw()
	t:eq(target, nil)
	t:eq(alpha, 1)
end)

test.post_processed_composite_keeps_its_canvas_when_opaque = withFakeCanvases(function(t)
	local screen = Screen()
	local composite = CompositeView()
	screen.root:add(composite:anchorFixed(0, 0, 100, 50))
	local passes = 0
	function composite:postProcess() passes = passes + 1 end
	screen:resize(800, 600)

	screen:draw()

	t:assert(canvasOf(composite) ~= nil)
	t:eq(passes, 1)
end)

test.hidden_composites_release_their_canvases = withFakeCanvases(function(t)
	local screen = Screen()
	local outer = addTranslucent(screen, 200, 100)
	local inner = outer:add(CompositeView():anchorFixed(0, 0, 100, 50))
	inner:setOpacity(0.5)
	screen:resize(800, 600)
	screen:draw()
	local outer_canvas, inner_canvas = canvasOf(outer), canvasOf(inner)

	outer:setVisible(false)

	t:eq(outer_canvas.released, true)
	t:eq(inner_canvas.released, true)
	t:eq(canvasOf(inner), nil)
	screen:draw()
	t:eq(canvasOf(outer), nil)
end)

return test
