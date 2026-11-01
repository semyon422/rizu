local NineSliceUsage = require("gui.NineSliceUsage")

local test = {}
local old_love = love

---@param t testing.T
function test.fixed_scale_cancels_ui_scale_and_expands_target(t)
	local calls = {}
	love = {
		graphics = {
			push = function(mode) calls[#calls + 1] = {"push", mode} end,
			scale = function(x, y) calls[#calls + 1] = {"scale", x, y} end,
			pop = function() calls[#calls + 1] = {"pop"} end,
		},
	}
	local usage = {
		draw = function(_, width, height)
			calls[#calls + 1] = {"draw", width, height}
		end,
	}
	setmetatable(usage, {__index = NineSliceUsage})

	usage:drawFixedScale(100, 50, 2)
	love = old_love

	t:tdeq(calls, {
		{"push", "transform"},
		{"scale", 0.5, 0.5},
		{"draw", 200, 100},
		{"pop"},
	})
end

---@param t testing.T
function test.fixed_scale_at_one_draws_without_transform_changes(t)
	local calls = {}
	love = {graphics = {
		push = function() calls[#calls + 1] = "push" end,
		scale = function() calls[#calls + 1] = "scale" end,
		pop = function() calls[#calls + 1] = "pop" end,
	}}
	local usage = {draw = function(_, width, height) calls[#calls + 1] = {width, height} end}
	setmetatable(usage, {__index = NineSliceUsage})

	usage:drawFixedScale(100, 50, 1)
	love = old_love

	t:tdeq(calls, {{100, 50}})
end

---@param t testing.T
function test.open_edges_repeat_the_middle_row(t)
	local sprites = {}
	for i = 1, 9 do
		sprites[i] = {i = i, getDimensions = function() return 10, 10 end}
	end
	local added = {}
	local usage = setmetatable({sprites = sprites, left_width = 10, center_width = 10, right_width = 10,
		top_height = 10, center_height = 10, bottom_height = 10, open_top = false, open_bottom = false,
		batch = {
			clear = function() added = {} end,
			add = function(_, sprite, x, y, r, sx, sy) added[#added + 1] = {sprite.i, y, sy} end,
			flush = function() end,
		},
	}, {__index = NineSliceUsage})

	usage:resize(30, 40)
	t:tdeq(added, {
		{1, 0, 1}, {2, 0, 1}, {3, 0, 1},
		{4, 10, 2}, {5, 10, 2}, {6, 10, 2},
		{7, 30, 1}, {8, 30, 1}, {9, 30, 1},
	})

	usage:setOpenEdges(true, false)
	t:tdeq(added[1], {4, 0, 1})
	t:tdeq(added[7], {7, 30, 1})

	usage:setOpenEdges(false, true)
	t:tdeq(added[1], {1, 0, 1})
	t:tdeq(added[9], {6, 30, 1})
end

return test
