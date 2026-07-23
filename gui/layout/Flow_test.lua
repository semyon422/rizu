local View = require("gui.View")
local Flow = require("gui.layout.Flow")

local test = {}

---@param w number
---@param h number
---@param children gui.View[]
---@param strategy gui.layout.Flow
---@return gui.View
local function arrangeTree(w, h, children, strategy)
	local parent = View()
	parent.width = w
	parent.height = h
	parent.arrange_strategy = strategy
	for _, child in ipairs(children) do
		parent:add(child)
	end
	parent:relayout()
	return parent
end

---@param w number
---@param h number
---@return gui.View
local function sizedView(w, h)
	local view = View()
	view.offset_max = {w, h}
	return view
end

---@param t testing.T
function test.row_places_authored_sizes_with_gap_and_alignment(t)
	local left = sizedView(10, 8)
	local right = sizedView(20, 12)
	arrangeTree(100, 20, {left, right}, Flow({gap = 5, align = 0.5}))
	t:eq(left.x, 0); t:eq(left.y, 6); t:eq(left.width, 10); t:eq(left.height, 8)
	t:eq(right.x, 15); t:eq(right.y, 4); t:eq(right.width, 20); t:eq(right.height, 12)
end

---@param t testing.T
function test.column_places_authored_sizes_and_end_aligns(t)
	local top = sizedView(10, 20)
	local bottom = sizedView(30, 5)
	arrangeTree(50, 100, {top, bottom}, Flow({direction = "column", gap = 3, align = 1}))
	t:eq(top.x, 40); t:eq(top.y, 0)
	t:eq(bottom.x, 20); t:eq(bottom.y, 23)
end

---@param t testing.T
function test.padding_uses_left_top_right_bottom(t)
	local child = sizedView(10, 10)
	arrangeTree(100, 80, {child}, Flow({padding = {5, 10, 15, 20}, align = 0.5}))
	t:eq(child.x, 5)
	t:eq(child.y, 30)
end

---@param t testing.T
function test.layout_ignore_does_not_consume_gap_or_space(t)
	local first = sizedView(10, 10)
	local ignored = sizedView(50, 50)
	ignored.layout_ignore = true
	local last = sizedView(20, 10)
	arrangeTree(100, 20, {first, ignored, last}, Flow({gap = 5}))
	t:eq(first.x, 0)
	t:eq(last.x, 15)
	t:eq(ignored.arranged, nil)
end

---@param t testing.T
function test.contentSize_sums_main_and_maxes_cross_with_padding(t)
	local parent = View()
	parent:add(sizedView(10, 8))
	parent:add(sizedView(20, 12))
	local flow = Flow({gap = 5, padding = {1, 2, 3, 4}})
	local w, h = flow:contentSize(parent)
	t:eq(w, 39)
	t:eq(h, 18)
end

---@param t testing.T
function test.column_contentSize(t)
	local parent = View()
	parent:add(sizedView(10, 20))
	parent:add(sizedView(30, 5))
	local flow = Flow({direction = "column", gap = 3, padding = 2})
	local w, h = flow:contentSize(parent)
	t:eq(w, 34)
	t:eq(h, 32)
end

---@param t testing.T
function test.invalid_config_errors(t)
	t:has_error(function() Flow({direction = "diagonal"}) end)
	t:has_error(function() Flow({gap = -1}) end)
	t:has_error(function() Flow({align = -0.1}) end)
	t:has_error(function() Flow({align = 1.1}) end)
	t:has_error(function() Flow({padding = {0, -1, 0, 0}}) end)
end

---@param t testing.T
function test.placement_anchors_error(t)
	local child = sizedView(10, 10)
	child.anchor_min = {0.5, 0}
	child.anchor_max = {0.5, 0}
	t:has_error(function()
		arrangeTree(100, 20, {child}, Flow())
	end)
end

---@param t testing.T
function test.relayout_is_idempotent_and_preserves_authored_offsets(t)
	local child = View()
	child.offset_min = {3, 4}
	child.offset_max = {13, 14}
	local parent = arrangeTree(100, 20, {child}, Flow())
	parent:relayout()
	t:tdeq(child.offset_min, {3, 4})
	t:tdeq(child.offset_max, {13, 14})
	t:eq(child.x, 0); t:eq(child.y, 0)
	t:eq(child.width, 10); t:eq(child.height, 10)
end

return test
