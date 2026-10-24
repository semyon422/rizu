local rizucalc = require("chart.scoring.rizucalc")

local test = {}

---@param keys integer
---@return number[]
---@return integer[]
local function pattern(keys)
	local times, cols = {}, {}
	for i = 0, 399 do
		times[i + 1] = i * 0.0625 + i % 3 * 0.01
		cols[i + 1] = (i * 5 + math.floor(i / 7)) % keys + 1
	end
	return times, cols
end

-- expected values come from calc/v2_4k.py, calc/v2_7k.py and calc/v1_14k.py on the same pattern
function test.matches_python(t)
	for layout, expected in pairs({["4key"] = 21.609827446882242, ["7key"] = 18.951679383994975, ["14key2scratch"] = 69.2441430872979}) do
		local layout_ = rizucalc.layouts[layout]
		local times, cols = pattern(#layout_.groups)
		t:aeq(rizucalc.rate(times, cols, layout_), expected, 1e-9)
	end
end

-- 7K maps onto the 4K scale through dans that feel alike, values from calc/write_user_diff.py dan_curve
function test.dan_curve(t)
	local map = rizucalc.layouts["7key"].map
	t:aeq(map(24.71), 17.08, 1e-9)
	t:aeq(map(123.30), 32.27, 1e-9)
	t:aeq(map(80), 26.3868875814303, 1e-9)
	t:aeq(map(150), 35.534576031050946, 1e-9)
	t:eq(map(1), 0)
end

function test.empty(t)
	t:eq(rizucalc.rate({}, {}, rizucalc.layouts["4key"]), 0)
	t:eq(rizucalc.calc({}, "4key", 1), 0)
	t:eq(rizucalc.calc({}, "5key", 1), nil)
end

---@param times number[]
---@param cols integer[]
---@param inputs string[]
local function notes(times, cols, inputs)
	local out = {}
	for i = 1, #times do
		out[i] = {time = times[i], column = cols[i], input = inputs[cols[i]]}
	end
	return out
end

function test.calc(t)
	local times, cols = pattern(7)
	local keys = {"key1", "key2", "key3", "key4", "key5", "key6", "key7", "scratch1"}
	local plain = rizucalc.calc(notes(times, cols, keys), "7key", 1)

	-- 7key1scratch is rated without its scratch
	local with_scratch = notes(times, cols, keys)
	table.insert(with_scratch, 3, {time = with_scratch[2].time, column = 8, input = "scratch1"})
	t:aeq(rizucalc.calc(with_scratch, "7key1scratch", 1), plain, 1e-9)

	-- a faster rate is the same chart with shorter times
	local fast = {}
	for i, time in ipairs(times) do
		fast[i] = time / 1.5
	end
	t:aeq(rizucalc.calc(notes(times, cols, keys), "7key", 1.5), rizucalc.calc(notes(fast, cols, keys), "7key", 1), 1e-9)
end

return test
