local FlowContainer = require("gui.layout.FlowContainer")
local Screen = require("gui.Screen")
local TrackContainer = require("gui.layout.TrackContainer")
local View = require("gui.View")

-- 28.07.2026 7fa9f45065326abc17f34be0486a8d9e30d7d1bf
-- GUI BENCH dense layout                  994 views    0.487 ms/pass     2.04 M views/s
-- GUI BENCH mutation+flush                994 views    0.510 ms/pass     1.95 M views/s
-- GUI BENCH layout+flatten+renderer       994 views    0.510 ms/pass     1.95 M views/s

local test = {}

local VIEW_COUNT = 994
local MAX_DEPTH = 5
local ITERATIONS = 2000

local function noopDraw() end

---@param name string
---@param nodes integer
---@param iterations integer
---@param callback fun()
local function benchmark(name, nodes, iterations, callback)
	callback() -- Warm up the relevant LuaJIT traces.
	collectgarbage("collect")
	local start_time = love.timer.getTime()
	for _ = 1, iterations do
		callback()
	end
	local elapsed = love.timer.getTime() - start_time
	local milliseconds = elapsed * 1000 / iterations
	local throughput = nodes * iterations / elapsed / 1000000
	print(("GUI BENCH %-28s %4d views  %7.3f ms/pass  %7.2f M views/s"):format(
		name, nodes, milliseconds, throughput
	))
end

---@param parent gui.View
---@param count integer
local function addFlowItems(parent, count)
	for i = 1, count do
		local item = View()
		item:setSize(16 + i % 5, 20)
		item:setDraw(noopDraw)
		parent:add(item)
	end
end

---@param parent gui.View
---@param count integer
local function addAnchoredItems(parent, count)
	for i = 1, count do
		local item = View()
		local left = (i - 1) / count
		item.anchor_min = {left, 0}
		item.anchor_max = {i / count, 1}
		item:setDraw(noopDraw)
		parent:add(item)
	end
end

---Builds a dense screen shaped like song select: fixed sidebar, header/body/footer,
---and many short rows. Alternating flow and manually anchored rows exercise both
---container arrangement and ordinary anchor resolution. It has 994 views and a
---maximum parent depth of five.
---@return gui.Screen
---@return gui.layout.FlowContainer body
local function makeDenseScreen()
	local screen = Screen()
	local shell = screen.root:add(TrackContainer({direction = "row"}))
	shell:anchorFill(0, 0, 0, 0)

	local sidebar = shell:add(FlowContainer({
		direction = "column",
		gap = 8,
		padding = {8, 8, 8, 8},
	}), 64)
	addFlowItems(sidebar, 12)

	local content = shell:add(TrackContainer({direction = "column"}), "*")
	local header = content:add(FlowContainer({
		direction = "row",
		gap = 12,
		align = 0.5,
		padding = {16, 8, 16, 8},
	}), 64)
	addFlowItems(header, 20)

	local body = content:add(FlowContainer({
		direction = "column",
		gap = 2,
		padding = {12, 8, 12, 8},
	}), "*")
	for row_index = 1, 85 do
		local row
		if row_index % 2 == 0 then
			row = FlowContainer({direction = "row", gap = 3, align = 0.5})
			row:setSize(1800, 24)
			addFlowItems(row, 10)
		else
			row = View()
			row:setSize(1800, 24)
			addAnchoredItems(row, 10)
		end
		body:add(row)
	end

	local footer = content:add(FlowContainer({
		direction = "row",
		gap = 10,
		align = 0.5,
		padding = {16, 8, 16, 8},
	}), 64)
	addFlowItems(footer, 20)

	screen.width = 1920
	screen.height = 1080
	screen.root.width = 1920
	screen.root.height = 1080
	return screen, body
end

---@param view gui.View
---@param depth integer
---@return integer count
---@return integer max_depth
local function measureTree(view, depth)
	local count = 1
	local max_depth = depth
	for i = 1, #view.children do
		local child_count, child_depth = measureTree(view.children[i], depth + 1)
		count = count + child_count
		max_depth = math.max(max_depth, child_depth)
	end
	return count, max_depth
end

---Pure worst-case layout without Screen cache or renderer work.
function test.dense_1000_view_layout()
	local screen = makeDenseScreen()
	local count, max_depth = measureTree(screen.root, 0)
	benchmark("dense layout", count, ITERATIONS, function()
		screen.root:relayout()
	end)
	assert(count == VIEW_COUNT)
	assert(max_depth == MAX_DEPTH)
end

---Full CPU-side rebuild: layout, flatten/update/draw caches, and renderer command
---generation. Renderer:draw is deliberately never called.
function test.dense_1000_view_screen_rebuild()
	local screen = makeDenseScreen()
	screen:relayout()
	local count = #screen.views
	benchmark("layout+flatten+renderer", count, ITERATIONS, function()
		screen:relayout()
	end)
	assert(count == VIEW_COUNT)
	assert(#screen.draw_views == 902)
	assert(screen.renderer.command_count == #screen.draw_views * 2)
end

---Simulates a layout-affecting style change every frame, including invalidation
---and Screen:flush coalescing rather than calling the internal rebuild directly.
function test.dense_1000_view_mutating_layout()
	local screen, body = makeDenseScreen()
	screen:flush()
	local gap = 1
	benchmark("mutation+flush", #screen.views, ITERATIONS, function()
		gap = 3 - gap
		body:setGap(gap)
		screen:flush()
	end)
	assert(#screen.views == VIEW_COUNT)
	assert(screen.dirty == false)
end

return test
