local InputMode = require("chart.core.InputMode")
local BaseScore = require("rizu.engine.ScoreEngine.scores.BaseScore")

local test = {}

---@param mode string
---@return string
local function hands(mode)
	local score = BaseScore()
	score:load({notes_count = 0, inputmode = mode})
	local t = {}
	for i, input in ipairs(InputMode(mode):getInputs()) do
		t[i] = score.columnHands[input]:sub(1, 1)
	end
	return table.concat(t)
end

---@param t testing.T
function test.hands_by_input_mode(t)
	t:eq(hands("4key"), "llrr")
	t:eq(hands("5key"), "llcrr")
	t:eq(hands("7key1scratch"), "lllcrrrs")
end

---@param t testing.T
function test.misses_are_counted_per_hand(t)
	local score = BaseScore()
	score:load({notes_count = 0, inputmode = "5key"})
	for _, column in ipairs({"key1", "key3", "key5", "key5"}) do
		score:miss({column = column})
	end
	local slice = score:getSlice()
	t:eq(slice.leftMissCount, 1)
	t:eq(slice.centerMissCount, 1)
	t:eq(slice.rightMissCount, 2)
	t:eq(slice.missCount, 4)
end

---@param t testing.T
function test.scratch_misses_are_separate(t)
	local score = BaseScore()
	score:load({notes_count = 0, inputmode = "7key1scratch"})
	score:miss({column = "scratch1"})
	local slice = score:getSlice()
	t:eq(slice.scratchMissCount, 1)
	t:eq(slice.centerMissCount, 0)
end

return test
