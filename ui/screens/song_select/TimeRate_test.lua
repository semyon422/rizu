local TimeRate = require("ui.screens.song_select.TimeRate")

local test = {}

---@param rate_type "linear"|"exp"
---@param value number
---@param linear_rate number
---@return table
local function updateText(rate_type, value, linear_rate)
	local view = {
		time_rate_model = {
			replayBase = {rate_type = rate_type, rate = linear_rate},
			get = function() return value end,
		},
		text_color = {1, 1, 1, 1},
	}
	TimeRate.updateText(view)
	return view
end

---@param t testing.T
function test.formats_linear_rate_as_multiplier(t)
	t:eq(updateText("linear", 1.25, 1.25).text, "1.25x")
end

---@param t testing.T
function test.displays_exponential_rate_value(t)
	t:eq(updateText("exp", -1, 2 ^ (-1 / 10)).text, "-1")
	t:eq(updateText("exp", 0, 1).text, "0")
	t:eq(updateText("exp", 1, 2 ^ (1 / 10)).text, "+1")
end

return test
