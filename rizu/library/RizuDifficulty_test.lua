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

---@param inputmode string
---@return integer
local function keys_of(inputmode)
	local layout = RizuDifficulty.layouts[inputmode]
	return layout.columns and #layout.columns or #layout.groups
end

-- expected values from `python3 -m calc.rizu_difficulty`
function test.matches_python(t)
	local expected = {
		["4key"] = 20.68494197276502,
		["5key"] = 19.703875715070943,
		["6key"] = 8.757242097596112,
		["7key"] = 10.776354898581378,
		["7key1scratch"] = 10.147363241284891,
		["8key"] = 15.465923152275414,
		["9key"] = 16.814820611106764,
		["10key"] = 19.796414202091725,
		["14key2scratch"] = 10.618113628813708,
		["18key2scratch"] = 11.161294937305538,
		["36key2scratch"] = 12.73592349012305,
	}
	for inputmode, value in pairs(expected) do
		t:aeq(RizuDifficulty.rate(pattern(keys_of(inputmode)), inputmode), value, 1e-9)
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
	local expected = {['4key'] = {27.67744991360159, 20.68494197276502, 18.389519006849213}, ['6key'] = {22.583464202839355, 8.757242097596112, 22.135710977322965}, ['7key'] = {18.539820742420964, 10.776354898581378, 17.236759772291723}}
	for inputmode, values in pairs(expected) do
		local total, rice, ln = RizuDifficulty.rate(ln_pattern(keys_of(inputmode)), inputmode)
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

-- 12K is 14K+2 with the right hand from key8, 3K is the first three 4K columns, 7K is 7K+1 with an empty scratch
-- (its last column) and 6K is 7K without the middle key
function test.mapped_columns(t)
	local notes = pattern(12)
	local as_14k = remap(notes, function(c) return c <= 6 and c or c + 1 end)
	t:aeq(RizuDifficulty.rate(notes, "12key"), RizuDifficulty.rate(as_14k, "14key2scratch"), 1e-9)
	local as_18k = remap(pattern(15), function(c) return c <= 8 and c or c + 2 end)
	t:aeq(RizuDifficulty.rate(pattern(15), "15key"), RizuDifficulty.rate(as_18k, "18key2scratch"), 1e-9)
	local as_36k = remap(pattern(20), function(c) return c <= 10 and c or c + 8 end)
	t:aeq(RizuDifficulty.rate(pattern(20), "20key"), RizuDifficulty.rate(as_36k, "36key2scratch"), 1e-9)
	t:aeq(RizuDifficulty.rate(pattern(3), "3key"), RizuDifficulty.rate(pattern(3), "4key"), 1e-9)
	t:aeq(RizuDifficulty.rate(pattern(7), "7key"), RizuDifficulty.rate(pattern(7), "7key1scratch"), 1e-9)
	local as_7k = remap(pattern(6), function(c) return c <= 3 and c or c + 1 end)
	t:aeq(RizuDifficulty.rate(pattern(6), "6key"), RizuDifficulty.rate(as_7k, "7key"), 1e-9)
	t:ne(RizuDifficulty.rate(pattern(8), "7key1scratch"), RizuDifficulty.rate(pattern(7), "7key"))
end

-- 2K is 4K with each key's notes alternating between two columns
function test.alternated_columns(t)
	local notes = pattern(2)
	local as_4k = remap(notes, function(c, i) return (c - 1) * 2 + (i - 1) % 2 + 1 end)
	t:aeq(RizuDifficulty.rate(notes, "2key"), RizuDifficulty.rate(as_4k, "4key"), 1e-9)
	t:ne(RizuDifficulty.rate(notes, "2key"), RizuDifficulty.rate(notes, "4key"))
end

function test.unrated(t)
	t:eq(RizuDifficulty.rate(pattern(4), "37key"), nil)
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

function test.dan_7k(t)
	local knots = RizuDifficulty.dans_7k
	t:eq(RizuDifficulty.dan(knots[1] - 5, "7key"), "Intro")
	t:eq(RizuDifficulty.dan(knots[2], "7key"), "1st")
	t:eq(RizuDifficulty.dan(knots[11], "7key"), "10th")
	t:eq(RizuDifficulty.dan(knots[14], "7key"), "Zenith")
	t:eq(RizuDifficulty.dan(100, "7key"), "Zenith+")
	t:eq(RizuDifficulty.dan(20, "37key"), nil)
	for i = 2, #knots do
		t:assert(knots[i] > knots[i - 1], "dan ratings must rise")
	end
end

return test
