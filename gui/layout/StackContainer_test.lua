local StackContainer = require("gui.layout.StackContainer")
local View = require("gui.View")

local test = {}

---@param width number
---@param height number
---@param container gui.layout.StackContainer
local function arrange(width, height, container)
	container.width = width
	container.height = height
	container:relayout()
end

---@param t testing.T
function test.fill_default_stretches_all_children_to_inner_rect(t)
	local first, second = View(), View()
	local container = StackContainer({first, second})
	arrange(100, 80, container)

	t:tdeq({first.x, first.y, first.width, first.height}, {0, 0, 100, 80})
	t:tdeq({second.x, second.y, second.width, second.height}, {0, 0, 100, 80})
end

---@param t testing.T
function test.padding_insets_inner_rect(t)
	local child = View()
	local container = StackContainer({padding = {5, 10, 15, 20}, child})
	arrange(100, 80, container)

	t:tdeq({child.x, child.y, child.width, child.height}, {5, 10, 80, 50})
end

---@param t testing.T
function test.alignment_uses_authored_size(t)
	local child = View():setSize(40, 20)
	local container = StackContainer({
		align_items_x = "center",
		align_items_y = "end",
		child,
	})
	arrange(100, 80, container)

	t:tdeq({child.x, child.y, child.width, child.height}, {30, 60, 40, 20})
end

---@param t testing.T
function test.child_set_alignment_overrides_container_alignment(t)
	local child = View():setSize(20, 40):setAlignment(0.5, 0.5)
	local container = StackContainer({child})
	arrange(100, 80, container)

	t:tdeq({child.x, child.y, child.width, child.height}, {40, 20, 20, 40})
end

---@param t testing.T
function test.non_fill_alignment_requires_authored_size(t)
	local container = StackContainer({align_items_x = "center", View()})
	t:has_error(function()
		arrange(100, 80, container)
	end)
end

---@param t testing.T
function test.invalid_configuration_errors(t)
	t:has_error(function()
		StackContainer({align_items_x = "middle"})
	end)
	t:has_error(function()
		StackContainer({padding = -1})
	end)
	t:has_error(function()
		StackContainer({padding = {0, 0, -1, 0}})
	end)
end

---@param t testing.T
function test.fit_content_uses_largest_authored_size_and_padding(t)
	local container = StackContainer({
		padding = 5,
		View():setSize(50, 30),
		View():setSize(80, 20),
	})
	local result = container:fitContent()

	t:eq(result, container)
	t:eq(container.offset_max[1] - container.offset_min[1], 90)
	t:eq(container.offset_max[2] - container.offset_min[2], 40)
end

return test
