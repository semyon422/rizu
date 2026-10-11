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

---@param t testing.T
test.canvas_follows_resolved_size_and_ui_scale = withFakeCanvases(function(t)
	local screen = Screen()
	screen:setUIScale(2)
	local composite = screen.root:add(CompositeView():anchorFixed(0, 0, 100, 50))

	screen:resize(800, 600)

	t:eq(composite.canvas:getWidth(), 200)
	t:eq(composite.canvas:getHeight(), 100)
	t:eq(composite.canvas_scale, 2)
end)

---@param t testing.T
test.resize_replaces_and_releases_canvas = withFakeCanvases(function(t)
	local screen = Screen()
	local composite = screen.root:add(CompositeView():anchorFixed(0, 0, 100, 50))
	screen:resize(800, 600)
	local old_canvas = composite.canvas

	composite:setSize(120, 60)
	screen:flush()

	t:ne(composite.canvas, old_canvas)
	t:eq(composite.canvas:getWidth(), 120)
	t:eq(composite.canvas == old_canvas, false)
end)

---@param t testing.T
test.unload_releases_canvas = withFakeCanvases(function(t)
	local screen = Screen()
	local composite = screen.root:add(CompositeView():anchorFixed(0, 0, 100, 50))
	screen:resize(800, 600)
	screen:load()
	local canvas = composite.canvas

	screen:unload()

	t:assert(canvas ~= nil)
	t:eq(composite.canvas, nil)
end)

---@param t testing.T
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

---@param t testing.T
test.renderer_draws_nested_composites = withFakeCanvases(function(t)
	local screen = Screen()
	local outer = screen.root:add(CompositeView():anchorFixed(10, 20, 200, 100))
	local inner = outer:add(CompositeView():anchorFixed(20, 10, 100, 50))
	local draws = 0
	local child = inner:add(View():anchorFill(0, 0, 0, 0))
	child:setDraw(function()
		draws = draws + 1
	end)
	screen:resize(800, 600)

	screen:draw()

	t:eq(draws, 1)
end)

return test
