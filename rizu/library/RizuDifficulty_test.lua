local RizuDifficulty = require("rizu.library.RizuDifficulty")

local test = {}

---The pattern of calc/rizu_difficulty.py's pattern().
---@param keys integer
---@return {time: number, column: integer}[]
local function pattern(keys)
	---@type {time: number, column: integer, input: string?}[]
	local notes = {}
	for i = 0, 399 do
		notes[i + 1] = {time = i * 0.0625 + i % 3 * 0.01, column = (i * 5 + math.floor(i / 7)) % keys + 1}
	end
	return notes
end

-- expected values from `python3 -m calc.rizu_difficulty`
function test.matches_python(t)
	local expected = {
		["4key"] = 21.86809954611741,
		["5key"] = 19.703875715070943,
		["6key"] = 26.316913020636893,
		["7key"] = 16.301515479785213,
		["8key"] = 15.465923152275414,
		["9key"] = 16.41469447877662,
		["10key"] = 19.796414202091725,
		["14key2scratch"] = 10.618113628813708,
	}
	for inputmode, value in pairs(expected) do
		local keys = #RizuDifficulty.layouts[inputmode].groups
		t:aeq(RizuDifficulty.rate(pattern(keys), inputmode), value, 1e-9)
	end
end

-- 7K+1 is rated as 7K without its scratch
function test.scratch(t)
	local notes = pattern(7)
	local with_scratch = pattern(7)
	table.insert(with_scratch, 3, {time = with_scratch[2].time, column = 8, input = "scratch1"})
	t:aeq(RizuDifficulty.rate(with_scratch, "7key1scratch"), RizuDifficulty.rate(notes, "7key"), 1e-9)
end

---@param notes {time: number, column: integer}[]
---@param f fun(column: integer, i: integer): integer column and the note's index in it to the new column
---@return {time: number, column: integer}[]
local function remap(notes, f)
	---@type {time: number, column: integer}[], {[integer]: integer}
	local out, count = {}, {}
	for i, n in ipairs(notes) do
		count[n.column] = (count[n.column] or 0) + 1
		out[i] = {time = n.time, column = f(n.column, count[n.column])}
	end
	return out
end

-- 12K is 14K+2 with the right hand from key8, 3K is the first three 4K columns
function test.mapped_columns(t)
	local notes = pattern(12)
	local as_14k = remap(notes, function(c) return c <= 6 and c or c + 1 end)
	t:aeq(RizuDifficulty.rate(notes, "12key"), RizuDifficulty.rate(as_14k, "14key2scratch"), 1e-9)
	t:aeq(RizuDifficulty.rate(pattern(3), "3key"), RizuDifficulty.rate(pattern(3), "4key"), 1e-9)
end

-- 2K is 4K with each key's notes alternating between two columns
function test.alternated_columns(t)
	local notes = pattern(2)
	local as_4k = remap(notes, function(c, i) return (c - 1) * 2 + (i - 1) % 2 + 1 end)
	t:aeq(RizuDifficulty.rate(notes, "2key"), RizuDifficulty.rate(as_4k, "4key"), 1e-9)
	t:ne(RizuDifficulty.rate(notes, "2key"), RizuDifficulty.rate(notes, "4key"))
end

function test.unrated(t)
	t:eq(RizuDifficulty.rate(pattern(4), "16key"), nil)
	t:eq(RizuDifficulty.rate({}, "4key"), 0)
end

return test
