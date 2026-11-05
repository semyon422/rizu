local RizuDifficulty = require("rizu.library.RizuDifficulty")

local test = {}

---The pattern of calc/rizu_difficulty.py's pattern().
---@param keys integer
---@return {time: number, column: integer, end_time: number?}[]
local function pattern(keys)
	---@type {time: number, column: integer, input: string?, end_time: number?}[]
	local notes = {}
	for i = 0, 399 do
		notes[i + 1] = {time = i * 0.0625 + i % 3 * 0.01, column = (i * 5 + math.floor(i / 7)) % keys + 1}
	end
	return notes
end

-- expected values from `python3 -m calc.rizu_difficulty`
function test.matches_python(t)
	local expected = {
		["4key"] = 20.68494197276502,
		["5key"] = 19.703875715070943,
		["6key"] = 26.316913020636893,
		["7key"] = 16.301515479785213,
		["8key"] = 15.465923152275414,
		["9key"] = 16.814820611106764,
		["10key"] = 19.796414202091725,
		["14key2scratch"] = 10.618113628813708,
	}
	for inputmode, value in pairs(expected) do
		local keys = #RizuDifficulty.layouts[inputmode].groups
		t:aeq(RizuDifficulty.rate(pattern(keys), inputmode), value, 1e-9)
	end
end

---The pattern of calc/ln_difficulty.py's pattern(): every even note held until 50 ms before the next note of its column.
---@param keys integer
---@return {time: number, column: integer, end_time: number?}[]
local function ln_pattern(keys)
	local notes = pattern(keys)
	for i = 1, #notes, 2 do
		for j = i + 1, #notes do
			if notes[j].column == notes[i].column then
				notes[i].end_time = notes[j].time - 0.05
				break
			end
		end
	end
	return notes
end

-- expected rating, short-note rating and LN level from `python3 -m calc.ln_difficulty`
function test.matches_python_ln(t)
	local expected = {['4key'] = {27.67744991360159, 20.68494197276502, 18.389519006849213}, ['6key'] = {43.834328334837814, 26.316913020636893, 40.41216184571936}, ['7key'] = {31.018170206960257, 16.301515479785213, 29.438235365720175}}
	for inputmode, values in pairs(expected) do
		local keys = #RizuDifficulty.layouts[inputmode].groups
		local total, rice, ln = RizuDifficulty.rate(ln_pattern(keys), inputmode)
		t:aeq(total, values[1], 1e-9)
		t:aeq(rice, values[2], 1e-9)
		t:aeq(ln, values[3], 1e-9)
	end
end

-- without long notes the rating is the short-note rating
function test.no_ln(t)
	local total, rice, ln = RizuDifficulty.rate(pattern(4), "4key")
	t:eq(total, rice)
	t:eq(ln, 0)
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

function test.dan(t)
	local knots = RizuDifficulty.dans_4k
	t:eq(RizuDifficulty.dan(0), "Intro")
	t:eq(RizuDifficulty.dan(knots[2]), "1st")
	t:eq(RizuDifficulty.dan(knots[12]), "Alpha")
	-- nearest dan, and the third of it: 10.4 is 10th+, 10.6 is alpha-
	t:eq(RizuDifficulty.dan(knots[11] + (knots[12] - knots[11]) * 0.4), "10th+")
	t:eq(RizuDifficulty.dan(knots[11] + (knots[12] - knots[11]) * 0.6), "Alpha-")
	t:eq(RizuDifficulty.dan(knots[11] + (knots[12] - knots[11]) * 0.1), "10th")
	t:eq(RizuDifficulty.dan(knots[19]), "Theta")
	t:eq(RizuDifficulty.dan(100), "Theta+")
	for i = 2, #knots do
		t:assert(knots[i] > knots[i - 1], "dan ratings must rise")
	end
end

return test
