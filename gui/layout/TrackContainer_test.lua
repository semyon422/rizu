local TrackContainer = require("gui.layout.TrackContainer")
local View = require("gui.View")

local test = {}

---@param width number
---@param height number
---@param container gui.layout.TrackContainer
local function arrange(width, height, container)
	container.width = width
	container.height = height
	container:relayout()
end

---@param t testing.T
function test.constructor_adds_array_children_with_default_tracks(t)
	local first = View()
	local second = View()
	local container = TrackContainer({first, second, direction = "row"})
	arrange(100, 10, container)

	t:tdeq(container.children, {first, second})
	t:eq(first.parent, container)
	t:eq(second.parent, container)
	t:tdeq({first.x, first.width, second.x, second.width}, {0, 50, 50, 50})
end

---@param t testing.T
function test.column_divides_main_axis_and_fills_cross_axis(t)
	local container = TrackContainer({direction = "column"})
	local header = container:add(View(), 70)
	local content = container:add(View(), "*")
	local footer = container:add(View(), 30)
	arrange(400, 300, container)

	t:tdeq({header.x, header.y, header.width, header.height}, {0, 0, 400, 70})
	t:tdeq({content.x, content.y, content.width, content.height}, {0, 70, 400, 200})
	t:tdeq({footer.x, footer.y, footer.width, footer.height}, {0, 270, 400, 30})
end

---@param t testing.T
function test.row_supports_percent_star_gap_and_padding(t)
	local container = TrackContainer({direction = "row", gap = 10, padding = {10, 5, 20, 15}})
	local left = container:add(View(), "25%")
	local middle = container:add(View())
	local right = container:add(View(), "*")
	arrange(430, 120, container)

	t:tdeq({left.x, left.y, left.width, left.height}, {10, 5, 100, 100})
	t:tdeq({middle.x, middle.y, middle.width, middle.height}, {120, 5, 140, 100})
	t:tdeq({right.x, right.y, right.width, right.height}, {270, 5, 140, 100})
end

---@param t testing.T
function test.insert_sets_track_size_and_order(t)
	local container = TrackContainer({direction = "row"})
	local second = container:add(View(), 20)
	local first = container:insert(1, View(), 30)
	arrange(100, 10, container)

	t:tdeq(container.children, {first, second})
	t:tdeq({first.x, first.width, second.x, second.width}, {0, 30, 30, 20})
end

---@param t testing.T
function test.track_size_is_parent_owned_and_mutable(t)
	local container = TrackContainer({direction = "column"})
	local child = container:add(View(), 20)
	container:setTrackSize(child, 40)
	arrange(100, 100, container)
	t:eq(child.height, 40)

	container:remove(child)
	t:eq(child.parent, nil)
end

---@param t testing.T
function test.invalid_track_size_errors(t)
	local container = TrackContainer()
	t:has_error(function()
		container:add(View(), "content")
	end)
end

return test
