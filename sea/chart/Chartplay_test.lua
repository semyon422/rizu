local Chartplay = require("sea.chart.Chartplay")
local Healths = require("sea.chart.Healths")
local Timings = require("sea.chart.Timings")
local Subtimings = require("sea.chart.Subtimings")

local test = {}

---@return sea.Chartplay
local function new_valid_chartplay()
	local chartplay = {
		accuracy = 0.02,
		const = false,
		created_at = os.time(),
		custom = false,
		replay_hash = "00000000000000000000000000000000",
		hash = "00000000000000000000000000000000",
		healths = nil,
		index = 1,
		judges = {},
		max_combo = 0,
		miss_count = 100,
		not_perfect_count = 100,
		pass = true,
		mode = "mania",
		modifiers = {},
		nearest = false,
		pause_count = 1,
		rate = 1,
		rate_type = "exp",
		rating = 0,
		rating_pp = 0,
		tap_only = false,
		timings = Timings("simple", 0.160),
		subtimings = nil,
	}
	return setmetatable(chartplay, Chartplay)
end

---@param t testing.T
function test.valid(t)
	t:assert(new_valid_chartplay():validate())
end

---@param t testing.T
function test.invalid_timings_subtimings_pair(t)
	local chartplay = new_valid_chartplay()
	chartplay.subtimings = Subtimings("scorev", 1)
	t:tdeq({chartplay:validate()}, {nil, "invalid timings-subtimings pair"})
end

return test
