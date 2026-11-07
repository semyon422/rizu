-- What patterns a chart is made of, section by section: a small neural network (calc/tune_patterns.py) trained either
-- on the skillsets of 10 s sections, MinaCalc's (MSD) on 4K and Prism's on 6K-8K, where the top label scores about 1,
-- or on hand-made pattern examples, with their labels. The labels come with the model. 10K and 14K have no skillset
-- teacher, so their models come only from hand-made examples.
-- Separate from Rizu Difficulty: it says what is in a chart, not how hard it is.

local InputMode = require("chart.core.InputMode")

local pattern_classifier = {}

pattern_classifier.WINDOW = 10 -- seconds a section looks at
pattern_classifier.HOP = 2.5 -- seconds between section starts

-- shortcut: 10K and 14K have models only after `calc.tune_patterns mine` writes them; 5K could learn from MinaCalc
-- 0.74 when needed
local MODELS = {
	[4] = "chart.scoring.pattern_classifier_4k",
	[6] = "chart.scoring.pattern_classifier_7k",
	[7] = "chart.scoring.pattern_classifier_7k",
	[8] = "chart.scoring.pattern_classifier_7k",
	[10] = "chart.scoring.pattern_classifier_10k",
	[14] = "chart.scoring.pattern_classifier_14k",
}

local function popcount(x)
	local c = 0
	while x ~= 0 do
		x = bit.band(x, x - 1)
		c = c + 1
	end
	return c
end

---@param list number[]
---@return number[]
local function sorted(list)
	local s = {} ---@type number[]
	for i, v in ipairs(list) do
		s[i] = v
	end
	table.sort(s)
	return s
end

---@param s number[] sorted
---@param q number
---@return number
local function quantile(s, q)
	if #s == 0 then
		return 0
	end
	local pos = 1 + (#s - 1) * q
	local lo = math.floor(pos)
	local hi = math.min(#s, lo + 1)
	return s[lo] + (s[hi] - s[lo]) * (pos - lo)
end

local function log2ms(seconds)
	return math.log(math.max(seconds, 0.001) * 1000) / math.log(2)
end

local function ratio(a, b)
	return b > 0 and a / b or 0
end

---Section starts: every HOP seconds from the first note while the section still starts before the last note.
---@param notes {time: number}[] sorted by time
---@return number[]
function pattern_classifier.starts(notes)
	local starts = {}
	if #notes == 0 then
		return starts
	end
	local first, last = notes[1].time, notes[#notes].time
	local t = first
	repeat
		table.insert(starts, t)
		t = first + #starts * pattern_classifier.HOP
	until t > last - pattern_classifier.WINDOW / 2
	return starts
end

pattern_classifier.FEATURES = {
	"keys", "nps", "nps_key", "rows",
	"size1", "size2", "size3", "size4", "size5", "mean_size", "chords",
	"dt_p10", "dt_p50", "dt_p90", "fast", "flam", "dt_entropy", "off_grid", "rhythm_change",
	"jack", "jack_fast", "jack_pressure", "col_dt_p50", "col_dt_p10",
	"repeat", "alternate", "change", "chord_overlap", "chord_overlap2", "roll", "bracket",
	"neighbor", "direction", "size_change", "two_back", "imbalance",
	"holds", "held", "tap_holding", "active", "release_only", "inverse", "hold_len",
}

local feature_index = {} ---@type {[string]: integer}
for i, name in ipairs(pattern_classifier.FEATURES) do
	feature_index[name] = i
end

---Features of the notes starting in [start, start + WINDOW), in the order of FEATURES.
---@param notes {time: number, column: integer, end_time: number?}[] sorted by time
---@param columns integer
---@param start number
---@param first integer? an index at or before the section's first note, to skip the scan from the chart's start
---@return number[]
function pattern_classifier.features(notes, columns, start, first)
	local window = pattern_classifier.WINDOW
	local stop = start + window

	---@type {time: number, mask: integer, size: integer, cols: integer[], head_hold: boolean}[]
	local rows = {}
	local holds = {} ---@type {time: number, end_time: number, column: integer}[]
	local n = 0
	local i = first or 1
	while notes[i] and notes[i].time < start do
		i = i + 1
	end
	while notes[i] and notes[i].time < stop do
		local note = notes[i]
		local t = note.time
		i = i + 1
		n = n + 1
		local row = rows[#rows]
		if not row or row.time ~= t then
			row = {time = t, mask = 0, size = 0, cols = {}, head_hold = false}
			table.insert(rows, row)
		end
		local bit_ = bit.lshift(1, note.column - 1)
		if bit.band(row.mask, bit_) == 0 then
			row.mask = bit.bor(row.mask, bit_)
			row.size = row.size + 1
			table.insert(row.cols, note.column)
		end
		if note.end_time and note.end_time > t then
			row.head_hold = true
			table.insert(holds, {time = t, end_time = note.end_time, column = note.column})
		end
	end
	local r = #rows

	local sizes = {0, 0, 0, 0, 0}
	local size_sum = 0
	for _, row in ipairs(rows) do
		table.sort(row.cols)
		sizes[math.min(row.size, 5)] = sizes[math.min(row.size, 5)] + 1
		size_sum = size_sum + row.size
	end

	-- row deltas
	local dts = {} ---@type number[]
	local fast, flam = 0, 0
	local buckets = {} ---@type {[integer]: integer}
	for i = 2, r do
		local dt = rows[i].time - rows[i - 1].time
		if dt < 1.2 then
			table.insert(dts, dt)
			if dt <= 0.08 then fast = fast + 1 end
			if dt <= 0.055 then flam = flam + 1 end
			local b = math.floor(dt * 1000 / 5 + 0.5)
			buckets[b] = (buckets[b] or 0) + 1
		end
	end
	local entropy = 0
	for _, c in pairs(buckets) do
		local p = c / #dts
		entropy = entropy - p * math.log(p)
	end
	local dts_sorted = sorted(dts)
	local dt_med = quantile(dts_sorted, 0.5)
	-- off grid: deltas that aren't a multiple of half the median delta, the window's rough 1/8 grid
	local off_grid, rhythm_change = 0, 0
	for i, dt in ipairs(dts) do
		local x = dt / math.max(dt_med, 0.001) * 2
		if math.abs(x - math.floor(x + 0.5)) > 0.12 or x < 0.75 then
			off_grid = off_grid + 1
		end
		if i > 1 and math.abs(math.log(dt / math.max(dts[i - 1], 0.001))) > 0.1 then
			rhythm_change = rhythm_change + 1
		end
	end

	-- columns and row patterns
	local last_hit = {} ---@type {[integer]: number}
	local col_count = {} ---@type {[integer]: integer}
	local col_dts, jack_values = {}, {} ---@type number[], number[]
	local jack, jack_fast, neighbor, two_back = 0, 0, 0, 0
	local repeat_, alternate, change = 0, 0, 0
	local chord_pairs, chord_overlap, chord_overlap2 = 0, 0, 0
	local roll, bracket, size_change = 0, 0, 0
	local direction, prev_col, prev_dir = 0, nil, 0
	for i, row in ipairs(rows) do
		local prev, prev2 = rows[i - 1], rows[i - 2]
		if prev then
			local shared = bit.band(row.mask, prev.mask)
			jack = jack + popcount(shared)
			if row.time - prev.time <= 0.2 then
				jack_fast = jack_fast + popcount(shared)
			end
			if row.mask == prev.mask then repeat_ = repeat_ + 1 end
			change = change + popcount(bit.bxor(row.mask, prev.mask)) / columns
			if row.size ~= prev.size then size_change = size_change + 1 end
			if prev.size >= 2 and row.size >= 2 and row.time - prev.time < 1 then
				chord_pairs = chord_pairs + 1
				if shared ~= 0 then chord_overlap = chord_overlap + 1 end
				if popcount(shared) >= 2 then chord_overlap2 = chord_overlap2 + 1 end
			end
			local disjoint_ordered = prev.cols[1] > row.cols[#row.cols] or prev.cols[#prev.cols] < row.cols[1]
			if disjoint_ordered then roll = roll + 1 end
			if prev2 then
				if row.mask == prev2.mask then alternate = alternate + 1 end
				if row.time - prev2.time <= 0.5 then
					two_back = two_back + popcount(bit.band(row.mask, prev2.mask))
				end
				-- mania-hub's bracket window: three chords in a row, none sharing a column or rolling
				local prev_disjoint = prev2.cols[1] > prev.cols[#prev.cols] or prev2.cols[#prev2.cols] < prev.cols[1]
				if row.size >= 2 and prev.size >= 2 and prev2.size >= 2 and not disjoint_ordered and not prev_disjoint
					and shared == 0 and bit.band(prev.mask, prev2.mask) == 0 then
					bracket = bracket + 1
				end
			end
		end
		for _, c in ipairs(row.cols) do
			col_count[c] = (col_count[c] or 0) + 1
			local last = last_hit[c]
			if last then
				local dt = row.time - last
				if dt < 1 then
					table.insert(jack_values, math.min(230, 15 / math.max(dt, 0.001)))
				end
				if dt < 1.6 then
					table.insert(col_dts, dt)
				end
			end
			for _, nc in ipairs({c - 1, c + 1}) do
				local t = last_hit[nc]
				if t and row.time - t > 0 and row.time - t < 0.26 then
					neighbor = neighbor + 1
					break
				end
			end
			if prev_col then
				local dir = c > prev_col and 1 or c < prev_col and -1 or 0
				if dir ~= 0 and prev_dir ~= 0 and dir ~= prev_dir then direction = direction + 1 end
				if dir ~= 0 then prev_dir = dir end
			end
			prev_col = c
		end
		for _, c in ipairs(row.cols) do
			last_hit[c] = row.time
		end
	end
	local imbalance = 0
	for c = 1, n > 0 and columns or 0 do
		imbalance = imbalance + math.abs((col_count[c] or 0) - n / columns) / n
	end

	-- long notes
	local held_time, release_only, inverse, coordinated = 0, 0, 0, 0
	local hold_lens = {} ---@type number[]
	local head_times = {} ---@type {[number]: true}
	for _, row in ipairs(rows) do
		head_times[row.time] = true
	end
	local next_in_col = {} ---@type {[integer]: number[]}
	for _, row in ipairs(rows) do
		for _, c in ipairs(row.cols) do
			next_in_col[c] = next_in_col[c] or {}
			table.insert(next_in_col[c], row.time)
		end
	end
	for _, h in ipairs(holds) do
		held_time = held_time + math.min(h.end_time, stop) - h.time
		table.insert(hold_lens, h.end_time - h.time)
		if not head_times[h.end_time] then release_only = release_only + 1 end
		for _, t in ipairs(next_in_col[h.column]) do
			if t >= h.end_time then
				if t - h.end_time <= 0.15 then inverse = inverse + 1 end
				break
			end
		end
	end
	-- rows with a press while an earlier hold is still down
	local tap_holding = 0
	local hi = 1
	local active_ends = {} ---@type number[]
	for _, row in ipairs(rows) do
		while hi <= #holds and holds[hi].time < row.time do
			table.insert(active_ends, holds[hi].end_time)
			hi = hi + 1
		end
		for k = #active_ends, 1, -1 do
			if active_ends[k] <= row.time then
				table.remove(active_ends, k)
			end
		end
		if #active_ends > 0 then
			tap_holding = tap_holding + 1
		end
	end
	local nholds = #holds
	local col_sorted = sorted(col_dts)

	return {
		columns, n / window, n / window / columns, r / window,
		ratio(sizes[1], r), ratio(sizes[2], r), ratio(sizes[3], r), ratio(sizes[4], r), ratio(sizes[5], r),
		ratio(size_sum, r) / columns, ratio(r - sizes[1], r),
		#dts > 0 and log2ms(quantile(dts_sorted, 0.1)) or 10, #dts > 0 and log2ms(dt_med) or 10,
		#dts > 0 and log2ms(quantile(dts_sorted, 0.9)) or 10,
		ratio(fast, #dts), ratio(flam, #dts), entropy, ratio(off_grid, #dts), ratio(rhythm_change, #dts - 1),
		ratio(jack, n), ratio(jack_fast, n), quantile(sorted(jack_values), 0.92) / 100,
		#col_dts > 0 and log2ms(quantile(col_sorted, 0.5)) or 11, #col_dts > 0 and log2ms(quantile(col_sorted, 0.1)) or 11,
		ratio(repeat_, r - 1), ratio(alternate, r - 2), ratio(change, r - 1),
		ratio(chord_overlap, chord_pairs), ratio(chord_overlap2, chord_pairs), ratio(roll, r - 1), ratio(bracket, r),
		ratio(neighbor, n), ratio(direction, n), ratio(size_change, r), ratio(two_back, n), imbalance,
		ratio(nholds, n), held_time / (window * columns), ratio(tap_holding, r), held_time / window,
		ratio(release_only, nholds), ratio(inverse, nholds), nholds > 0 and log2ms(quantile(sorted(hold_lens), 0.5)) or 0,
	}
end

---@class chart.scoring.pattern_classifier.Model
---@field source "skillsets"|"examples"? what it was trained on: MSD/Prism skillsets or hand-made examples
---@field labels string[]
---@field mean number[]
---@field std number[]
---@field layers {w: number[][], b: number[]}[]

---@param model chart.scoring.pattern_classifier.Model
---@param x number[]
---@return number[]
local function forward(model, x)
	local h = {} ---@type number[]
	for i, v in ipairs(x) do
		h[i] = (v - model.mean[i]) / model.std[i]
	end
	for li, layer in ipairs(model.layers) do
		local out = {} ---@type number[]
		local last = li == #model.layers
		for j, b in ipairs(layer.b) do
			local s = b
			local w = layer.w[j]
			for i = 1, #h do
				s = s + w[i] * h[i]
			end
			out[j] = last and 1 / (1 + math.exp(-s)) or math.max(0, s)
		end
		h = out
	end
	return h
end

---@class chart.scoring.pattern_classifier.Section
---@field time number section start, seconds
---@field nps number
---@field bpm number? 1/4 rows at this BPM have the section's median row gap, the BPM players give a pattern; nil without rows
---@field labels {[string]: number} the model's label scores, 0-1

---The notes without scratch columns, the rest renumbered: 7K+1 reads as 7K and 14K2S as 14K, scratches don't change
---the patterns.
---@param notes {time: number, column: integer, end_time: number?}[]
---@param inputmode string
---@return {time: number, column: integer, end_time: number?}[]
---@return integer keys
function pattern_classifier.without_scratch(notes, inputmode)
	local key_of = {} ---@type {[integer]: integer}
	local columns = 0
	local inputs = InputMode(inputmode):getInputs()
	for i, input in ipairs(inputs) do
		if input:match("^key%d+$") then
			columns = columns + 1
			key_of[i] = columns
		end
	end
	if columns == #inputs then
		return notes, columns
	end
	local keys = {}
	for _, note in ipairs(notes) do
		local column = key_of[note.column]
		if column then
			table.insert(keys, {time = note.time, column = column, end_time = note.end_time})
		end
	end
	return keys, columns
end

---Sections of a chart with their pattern scores, or nil for keymodes without a model. Scratches are left out.
---@param notes {time: number, column: integer, end_time: number?}[] sorted by time
---@param inputmode string
---@param step fun()? called after each section, e.g. coroutine.yield to spread the work over frames
---@return chart.scoring.pattern_classifier.Section[]?
function pattern_classifier.analyze(notes, inputmode, step)
	local columns
	notes, columns = pattern_classifier.without_scratch(notes, inputmode)
	local name = MODELS[columns]
	if not name then
		return
	end
	local ok, loaded = pcall(require, name)
	if not ok then
		if tostring(loaded):find("not found", 1, true) then
			return
		end
		error(loaded)
	end
	local model = loaded --[[@as chart.scoring.pattern_classifier.Model]]
	local dt_p50, rows = feature_index.dt_p50, feature_index.rows
	local sections = {}
	local first = 1
	for _, start in ipairs(pattern_classifier.starts(notes)) do
		while notes[first].time < start do
			first = first + 1
		end
		local x = pattern_classifier.features(notes, columns, start, first)
		local y = forward(model, x)
		local labels = {} ---@type {[string]: number}
		for i, label in ipairs(model.labels) do
			labels[label] = y[i]
		end
		local bpm = x[rows] >= 2 and 15000 / 2 ^ x[dt_p50] or nil -- dt_p50 is log2 of the gap in ms
		table.insert(sections, {time = start, nps = x[2], bpm = bpm, labels = labels})
		if step then
			step()
		end
	end
	return sections
end

return pattern_classifier
