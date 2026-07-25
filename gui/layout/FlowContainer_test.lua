local FlowContainer = require("gui.layout.FlowContainer")
local View = require("gui.View")

local test = {}

---@param width number
---@param height number
---@param container gui.layout.FlowContainer
local function arrange(width, height, container)
	container.width = width
	container.height = height
	container:relayout()
end

---@param t testing.T
function test.row_packs_authored_sizes_and_aligns_cross_axis(t)
	local first = View():setSize(20, 30)
	local second = View():setSize(40, 10)
	local container = FlowContainer({
		direction = "row",
		gap = 5,
		align = 0.5,
		padding = {10, 10, 20, 10},
		first,
		second,
	})
	arrange(200, 100, container)

	t:tdeq({first.x, first.y, first.width, first.height}, {10, 35, 20, 30})
	t:tdeq({second.x, second.y, second.width, second.height}, {35, 45, 40, 10})
end

---@param t testing.T
function test.column_packs_authored_sizes(t)
	local first = View():setSize(20, 30)
	local second = View():setSize(40, 10)
	local container = FlowContainer({direction = "column", gap = 5, first, second})
	arrange(100, 100, container)

	t:tdeq({first.x, first.y, first.width, first.height}, {0, 0, 20, 30})
	t:tdeq({second.x, second.y, second.width, second.height}, {0, 35, 40, 10})
end

---@param t testing.T
function test.fit_content_sets_authored_size(t)
	local container = FlowContainer({
		direction = "row",
		gap = 5,
		padding = 10,
		View():setSize(20, 30),
		View():setSize(40, 10),
	})
	local result = container:fitContent()

	t:eq(result, container)
	t:eq(container.offset_max[1] - container.offset_min[1], 85)
	t:eq(container.offset_max[2] - container.offset_min[2], 50)
end

---@param t testing.T
function test.fit_content_preserves_recorded_alignment(t)
	local container = FlowContainer({View():setSize(20, 10)})
	container:setAlignment(1, 0.5)
	container:fitContent()

	t:tdeq(container.offset_min, {-20, -5})
	t:tdeq(container.offset_max, {0, 5})
end

---@param t testing.T
function test.layout_ignore_excludes_child_from_arrangement_and_measurement(t)
	local container = FlowContainer({direction = "column", gap = 5})
	container:setSize(100, 100)
	local first = View():setSize(20, 10)
	local ignored = View():setSize(80, 70):setLayoutIgnore(true)
	local second = View():setSize(20, 10)
	ignored:anchorFixed(40, 50, 80, 70)
	container:add(first)
	container:add(ignored)
	container:add(second)

	container:relayout()
	local width, height = container:getContentSize()

	t:eq(first.y, 0)
	t:eq(second.y, 15)
	t:eq(ignored.x, 40)
	t:eq(ignored.y, 50)
	t:eq(width, 20)
	t:eq(height, 25)
end

return test
