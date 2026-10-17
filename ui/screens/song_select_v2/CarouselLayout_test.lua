local CarouselLayout = require("ui.screens.song_select_v2.CarouselLayout")
local test = {}

local function newLayout()
	local layout = CarouselLayout(10, 2, 4, 1)
	layout:setSetCount(5)
	return layout
end

---@param t testing.T
function test.closed_layout_is_a_plain_list(t)
	local layout = newLayout()
	t:eq(layout:getContentHeight(), 5 * 12 - 2)
	t:eq(layout:getSetY(3), 24)
	t:tdeq({layout:locate(25)}, {"set", 3})
	-- A gap is split between the rows around it.
	t:tdeq({layout:locate(10.5)}, {"set", 1})
	t:tdeq({layout:locate(11)}, {"set", 2})
	t:tdeq({layout:locate(5 * 12 - 2 + 0.5)}, {"set", 5})
	t:eq(layout:locate(5 * 12), nil)
end

---@param t testing.T
function test.open_group_pushes_following_sets_down(t)
	local layout = newLayout()
	layout:expand(2, 3)
	t:eq(layout:getSetY(3, true), 24 + 3 * 5)
	t:eq(layout:getSetY(2, true), 12)
	t:eq(layout:getContentHeight(true), 5 * 12 - 2 + 15)
	t:eq(layout:getSetY(3), 24) -- animation has not started

	layout:update(1)
	t:eq(layout:getSetY(3), 24 + 15)
	t:tdeq({layout:locate(24 + 5)}, {"child", 2, 2})
	t:tdeq({layout:locate(24 + 15 + 1)}, {"set", 3})
	t:tdeq({layout:locate(22.5)}, {"set", 2})
	t:tdeq({layout:locate(23)}, {"child", 2, 1})
	t:tdeq({layout:locate(24 + 4.6)}, {"child", 2, 2})
	t:tdeq({layout:locate(24 + 15 - 0.4)}, {"set", 3})
end

---@param t testing.T
function test.switching_groups_closes_the_old_one_and_drops_it(t)
	local layout = newLayout()
	layout:expand(1, 2)
	layout:update(1)
	layout:expand(4, 2)
	t:eq(layout:getSetY(5, true), 4 * 12 + 10)
	layout:update(CarouselLayout.CLOSE_HALF_LIFE)
	t:eq(#layout.groups, 2)
	layout:update(1)
	t:eq(#layout.groups, 1)
	t:eq(layout.groups[1].index, 4)
	t:eq(layout:isAnimating(), false)
end

---@param t testing.T
function test.visit_reports_only_visible_rows(t)
	local layout = newLayout()
	layout:expand(2, 3)
	layout:update(1)
	local sets, children = {}, {}
	layout:visit(20, 45, function(i) table.insert(sets, i) end, function(_, j) table.insert(children, j) end)
	t:tdeq(sets, {2, 3})
	t:tdeq(children, {3, 2, 1})
end

---@param t testing.T
function test.closing_rows_stay_in_place_and_fade_out(t)
	local layout = newLayout()
	layout:expand(2, 3)
	layout:update(1)
	local function rows()
		local ys, alphas = {}, {}
		layout:visit(0, 200, function() end, function(_, j, y, alpha) ys[j], alphas[j] = y, alpha end)
		return ys, alphas
	end
	local before = rows()
	layout:collapse()
	layout:update(layout.FADE_TIME / 2)
	local ys, alphas = rows()
	t:tdeq(ys, before)
	t:eq(alphas[1] > 0 and alphas[1] < 1, true)
	t:eq(layout:locate(24 + 5) ~= "child", true) -- not clickable
	layout:update(1)
	t:eq(#layout.groups, 0)
end

return test
