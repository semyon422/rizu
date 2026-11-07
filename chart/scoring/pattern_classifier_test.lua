local pattern_classifier = require("chart.scoring.pattern_classifier")

local test = {}

---Rows on a 1/4 grid at a BPM for 12 s, columns from a list of rows repeated in order.
---@param bpm number
---@param pattern integer[][]
---@return {time: number, column: integer}[]
local function chart(bpm, pattern)
	local notes = {}
	local dt = 15 / bpm
	local i = 0
	while i * dt < 12 do
		for _, column in ipairs(pattern[i % #pattern + 1]) do
			table.insert(notes, {time = i * dt, column = column})
		end
		i = i + 1
	end
	return notes
end

---@param sections chart.scoring.pattern_classifier.Section[]
---@return string
local function top(sections)
	local best, value = "", -1
	for label, v in pairs(sections[1].labels) do
		if v > value then
			best, value = label, v
		end
	end
	return best
end

---Checks the top label of a pattern on the MSD/Prism models; models of hand-made examples (`calc.tune_patterns mine`)
---have their own labels.
---@param t table
---@param inputmode string
---@param want string
---@param notes {time: number, column: integer}[]
local function expect(t, inputmode, want, notes)
	local model = require(inputmode == "4key" and "chart.scoring.pattern_classifier_4k" or "chart.scoring.pattern_classifier_7k") --[[@as chart.scoring.pattern_classifier.Model]]
	if model.source == "examples" then
		return
	end
	t:eq(top(assert(pattern_classifier.analyze(notes, inputmode))), want)
end

function test.sections(t)
	local notes = chart(180, {{1}, {2}, {3}, {4}})
	t:eq(#pattern_classifier.starts(notes), 3)
	t:eq(#pattern_classifier.features(notes, 4, 0), #pattern_classifier.FEATURES)
	t:eq(pattern_classifier.analyze(notes, "5key"), nil)
end

function test.bpm(t)
	local sections = assert(pattern_classifier.analyze(chart(180, {{1}, {3}, {2}, {4}}), "4key"))
	t:assert(math.abs(sections[1].bpm - 180) < 0.01)
	t:eq(assert(pattern_classifier.analyze({{time = 0, column = 1}}, "4key"))[1].bpm, nil)
end

function test.labels_4k(t)
	expect(t, "4key", "stream", chart(200, {{1}, {3}, {2}, {4}, {1}, {3}, {4}, {2}}))
	expect(t, "4key", "jumpstream", chart(190, {{1, 2}, {4}, {1}, {2, 3}, {4}, {1, 3}, {2}, {3, 4}}))
	expect(t, "4key", "handstream", chart(170, {{1, 2, 4}, {3}, {1, 2, 3}, {4}, {2, 3, 4}, {1}}))
	expect(t, "4key", "jackspeed", chart(190, {{1}, {1}, {2}, {2}, {4}, {4}, {3}, {3}}))
	expect(t, "4key", "chordjack", chart(150, {{1, 2, 4}, {1, 3}, {2, 3, 4}, {2, 4}}))
end

function test.labels_7k(t)
	expect(t, "7key", "stream", chart(220, {{1}, {3}, {5}, {7}, {2}, {4}, {6}, {4}}))
	expect(t, "7key", "jumpstream", chart(170, {{1, 3}, {5, 7}, {2, 4}, {6}, {1, 5}, {3, 7}, {2, 6}, {4}}))
	expect(t, "7key", "chordjack", chart(140, {{1, 2, 5}, {2, 5, 6}, {1, 5, 7}, {2, 3, 5}}))
end

function test.without_scratch_counts_keys(t)
	local notes = {{time = 0, column = 1}, {time = 0, column = 10}}
	local keys, columns = pattern_classifier.without_scratch(notes, "10key")
	t:eq(columns, 10)
	t:eq(#keys, 2)
	keys, columns = pattern_classifier.without_scratch({
		{time = 0, column = 1}, {time = 0, column = 14}, {time = 0, column = 15}, {time = 0, column = 16},
	}, "14key2scratch")
	t:eq(columns, 14)
	t:eq(#keys, 2)
	t:eq(keys[2].column, 14)
end

function test.scratch_is_ignored(t)
	local keys = chart(170, {{1, 3}, {5, 7}, {2, 4}, {6}, {1, 5}, {3, 7}, {2, 6}, {4}})
	local with_scratch = {}
	for i, note in ipairs(keys) do
		table.insert(with_scratch, note)
		if i % 3 == 0 then
			table.insert(with_scratch, {time = note.time, column = 8}) -- scratch1 is the 8th column of 7key1scratch
		end
	end
	local a = assert(pattern_classifier.analyze(keys, "7key"))
	local b = assert(pattern_classifier.analyze(with_scratch, "7key1scratch"))
	t:eq(#b, #a)
	t:tdeq(b[1].labels, a[1].labels)
end

return test
