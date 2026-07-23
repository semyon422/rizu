local View = require("gui.View")
local Flex = require("gui.layout.Flex")

local test = {}

---@param w number
---@param h number
---@param children gui.View[]
---@param strategy gui.layout.Flex
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
function test.row_all_star_splits_inner_equally(t)
	local a, b = View(), View()
	arrangeTree(300, 100, {a, b}, Flex({direction = "row"}))
	t:eq(a.width, 150); t:eq(b.width, 150)
	t:eq(a.height, 100); t:eq(b.height, 100)
	t:eq(a.x, 0); t:eq(b.x, 150)
end

---@param t testing.T
function test.column_all_star_splits_inner_vertically(t)
	local a, b = View(), View()
	arrangeTree(100, 300, {a, b}, Flex({direction = "column"}))
	t:eq(a.height, 150); t:eq(b.height, 150)
	t:eq(a.width, 100); t:eq(b.width, 100)
	t:eq(a.y, 0); t:eq(b.y, 150)
end

---@param t testing.T
function test.fixed_then_star_gets_remainder(t)
	local a, b, c = View(), View(), View()
	arrangeTree(300, 100, {a, b, c}, Flex({direction = "row", sizes = {100, "*", 50}}))
	t:eq(a.x, 0);     t:eq(a.width, 100)
	t:eq(b.x, 100);   t:eq(b.width, 150)
	t:eq(c.x, 250);   t:eq(c.width, 50)
end

---@param t testing.T
function test.percent_size_of_inner_main(t)
	local a, b = View(), View()
	arrangeTree(400, 100, {a, b}, Flex({direction = "row", sizes = {"25%", "*"}}))
	t:eq(a.width, 100)
	t:eq(b.width, 300)
end

---@param t testing.T
function test.content_uses_authored_main_axis_size(t)
	local a, b = View(), View()
	a:setSize(70, 20)
	b:setSize(40, 30)
	arrangeTree(300, 100, {a, b}, Flex({direction = "row", sizes = {"*", "content"}}))
	t:eq(a.width, 260)
	t:eq(b.x, 260)
	t:eq(b.width, 40)
end

---@param t testing.T
function test.content_uses_authored_height_in_column(t)
	local a = View()
	a:setSize(20, 35)
	arrangeTree(100, 100, {a}, Flex({direction = "column", sizes = {"content"}, justify = "end"}))
	t:eq(a.y, 65)
	t:eq(a.height, 35)
end

---@param t testing.T
function test.sizes_shorter_than_children_pads_with_star(t)
	local a, b, c = View(), View(), View()
	arrangeTree(300, 100, {a, b, c}, Flex({direction = "row", sizes = {100}}))
	t:eq(a.width, 100)
	t:eq(b.width, 100)
	t:eq(c.width, 100)
end

---@param t testing.T
function test.gap_inserted_between_children(t)
	local a, b, c = View(), View(), View()
	arrangeTree(320, 100, {a, b, c}, Flex({direction = "row", gap = 10, sizes = {100, 100, "*"}}))
	t:eq(a.x, 0)
	t:eq(b.x, 110)
	t:eq(c.x, 220)
	t:eq(c.width, 100)
end

---@param t testing.T
function test.padding_number_insets_inner_rect(t)
	local a = View()
	arrangeTree(100, 100, {a}, Flex({direction = "row", padding = 10}))
	t:eq(a.x, 10); t:eq(a.y, 10)
	t:eq(a.width, 80); t:eq(a.height, 80)
end

---@param t testing.T
function test.padding_table_left_top_right_bottom(t)
	local a = View()
	arrangeTree(100, 100, {a}, Flex({direction = "row", padding = {5, 10, 15, 20}}))
	t:eq(a.x, 5); t:eq(a.y, 10)
	t:eq(a.width, 80); t:eq(a.height, 70)
end

---@param t testing.T
function test.align_items_center_uses_desired_cross_size(t)
	local a = View()
	a.offset_max = {0, 40}
	arrangeTree(200, 100, {a}, Flex({direction = "row", sizes = {"*"}, align_items = "center"}))
	t:eq(a.height, 40)
	t:eq(a.y, 30)
end

---@param t testing.T
function test.align_self_overrides_align_items_on_cross(t)
	local a = View()
	a.offset_max = {0, 20}
	a.align_self = "end"
	arrangeTree(200, 100, {a}, Flex({direction = "row", sizes = {"*"}, align_items = "fill"}))
	t:eq(a.height, 20)
	t:eq(a.y, 80)
end

---@param t testing.T
function test.justify_start_packs_at_start(t)
	local a, b = View(), View()
	arrangeTree(300, 100, {a, b}, Flex({direction = "row", sizes = {50, 50}, justify = "start"}))
	t:eq(a.x, 0); t:eq(b.x, 50)
end

---@param t testing.T
function test.justify_center_with_leftover(t)
	local a, b = View(), View()
	arrangeTree(300, 100, {a, b}, Flex({direction = "row", sizes = {50, 50}, justify = "center"}))
	-- leftover = 300 - 100 = 200, offset = 100
	t:eq(a.x, 100); t:eq(b.x, 150)
end

---@param t testing.T
function test.justify_end_with_leftover(t)
	local a, b = View(), View()
	arrangeTree(300, 100, {a, b}, Flex({direction = "row", sizes = {50, 50}, justify = "end"}))
	-- leftover = 200, offset = 200
	t:eq(a.x, 200); t:eq(b.x, 250)
end

---@param t testing.T
function test.justify_ignored_when_flex_consumes_leftover(t)
	local a, b = View(), View()
	arrangeTree(300, 100, {a, b}, Flex({direction = "row", sizes = {"*", "*"}, justify = "center"}))
	-- flex consumes all leftover, justify has nothing to distribute
	t:eq(a.x, 0); t:eq(b.x, 150)
end

---@param t testing.T
function test.layout_ignore_child_keeps_nil_arranged(t)
	local a, ignored = View(), View()
	ignored.layout_ignore = true
	ignored.anchor_max = {1, 1}
	arrangeTree(200, 100, {a, ignored}, Flex({direction = "row", sizes = {100}}))
	t:eq(a.width, 100)
	t:eq(ignored.arranged, nil)
	t:eq(ignored.width, 200)  -- resolved from fill anchors
end

---@param t testing.T
function test.invalid_direction_errors(t)
	t:has_error(function()
		Flex({direction = "diagonal"})
	end)
end

---@param t testing.T
function test.invalid_justify_errors(t)
	t:has_error(function()
		Flex({justify = "space_between"})
	end)
end

---@param t testing.T
function test.invalid_align_errors(t)
	t:has_error(function()
		Flex({align_items = "middle"})
	end)
end

---@param t testing.T
function test.invalid_size_spec_errors(t)
	t:has_error(function()
		Flex({sizes = {true}})
	end)
	t:has_error(function()
		Flex({sizes = {"abc"}})
	end)
	t:has_error(function()
		Flex({sizes = {-50}})
	end)
end

---@param t testing.T
function test.negative_gap_and_padding_error(t)
	t:has_error(function()
		Flex({gap = -1})
	end)
	t:has_error(function()
		Flex({padding = -1})
	end)
end

---@param t testing.T
function test.contentSize_sums_main_axis_max_cross_with_padding(t)
	local parent = View()
	local a, b = View(), View()
	a.offset_max = {80, 30}
	b.offset_max = {0, 50}
	parent:add(a)
	parent:add(b)
	local flex = Flex({direction = "row", gap = 4, padding = 5, sizes = {"content", 200}})
	local w, h = flex:contentSize(parent)
	-- main = 80 + 4 + 200 + 5 + 5 = 294, cross = max(30, 50) + 5 + 5 = 60
	t:eq(w, 294)
	t:eq(h, 60)
end

return test
