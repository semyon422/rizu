local View = require("gui.View")
local Stack = require("gui.layout.Stack")

local test = {}

---Build a parent sized (w, h) with children added, run relayout, return parent.
---@param w number
---@param h number
---@param children gui.View[]
---@param strategy gui.ArrangeStrategy?
---@return gui.View
local function arrangeTree(w, h, children, strategy)
	local parent = View()
	parent.width = w
	parent.height = h
	parent.arrange_strategy = strategy
	for _, c in ipairs(children) do
		parent:add(c)
	end
	parent:relayout()
	return parent
end

---@param t testing.T
function test.fill_default_stretches_to_inner_rect(t)
	local a, b = View(), View()
	arrangeTree(100, 80, {a, b}, Stack())
	t:eq(a.x, 0); t:eq(a.y, 0); t:eq(a.width, 100); t:eq(a.height, 80)
	t:eq(b.x, 0); t:eq(b.y, 0); t:eq(b.width, 100); t:eq(b.height, 80)
end

---@param t testing.T
function test.padding_number_insets_inner_rect(t)
	local a = View()
	arrangeTree(100, 80, {a}, Stack({padding = 10}))
	t:eq(a.x, 10); t:eq(a.y, 10)
	t:eq(a.width, 80); t:eq(a.height, 60)
end

---@param t testing.T
function test.padding_table_left_top_right_bottom(t)
	local a = View()
	arrangeTree(100, 80, {a}, Stack({padding = {5, 10, 15, 20}}))
	t:eq(a.x, 5); t:eq(a.y, 10)
	t:eq(a.width, 80); t:eq(a.height, 50)
end

---@param t testing.T
function test.center_x_with_desired_width(t)
	local a = View()
	a.offset_max = {40, 0}
	arrangeTree(100, 80, {a}, Stack({align_items_x = "center"}))
	t:eq(a.x, 30); t:eq(a.width, 40)
	t:eq(a.y, 0); t:eq(a.height, 80)
end

---@param t testing.T
function test.end_y_with_desired_height(t)
	local a = View()
	a.offset_max = {0, 20}
	arrangeTree(100, 80, {a}, Stack({align_items_y = "end"}))
	t:eq(a.y, 60); t:eq(a.height, 20)
end

---@param t testing.T
function test.align_self_overrides_container(t)
	local a = View()
	a.offset_max = {20, 40}
	a.align_self = "center"
	arrangeTree(100, 80, {a}, Stack({align_items_x = "fill", align_items_y = "fill"}))
	t:eq(a.x, 40); t:eq(a.width, 20)
	t:eq(a.y, 20); t:eq(a.height, 40)
end

---@param t testing.T
function test.layout_ignore_child_keeps_nil_arranged(t)
	local a, ignored = View(), View()
	ignored.layout_ignore = true
	ignored.anchor_max = {1, 1}
	arrangeTree(100, 80, {a, ignored}, Stack())
	t:eq(a.width, 100)
	t:eq(ignored.arranged, nil)
	-- Ignored child still resolves from its own anchors (§5): fill = 100x80.
	t:eq(ignored.width, 100)
	t:eq(ignored.height, 80)
end

---@param t testing.T
function test.non_fill_align_with_zero_desired_is_error(t)
	local a = View()
	t:has_error(function()
		arrangeTree(100, 80, {a}, Stack({align_items_x = "center"}))
	end)
end

---@param t testing.T
function test.invalid_align_value_errors(t)
	t:has_error(function()
		Stack({align_items_x = "middle"})
	end)
end

---@param t testing.T
function test.negative_padding_errors(t)
	t:has_error(function()
		Stack({padding = -1})
	end)
	t:has_error(function()
		Stack({padding = {0, 0, -1, 0}})
	end)
end

---@param t testing.T
function test.contentSize_returns_max_desired_plus_padding(t)
	local parent = View()
	local a, b = View(), View()
	a.offset_max = {50, 30}
	b.offset_max = {80, 20}
	parent:add(a)
	parent:add(b)
	local stack = Stack({padding = 5})
	local w, h = stack:contentSize(parent)
	t:eq(w, 90)
	t:eq(h, 40)
end

return test
