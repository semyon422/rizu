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

return test
