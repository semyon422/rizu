-- SPDX-License-Identifier: Unlicense
-- This file is released into the public domain, unlike the rest of the repository (GPL-3.0).
-- Anyone may copy, modify, publish, use, sell or distribute it, in source or compiled form, for any purpose, with no
-- warranty. See https://unlicense.org.

local rizucalc = require("chart.scoring.rizucalc")
local rizucalc_ln = require("chart.scoring.rizucalc_ln")

---Rizu Difficulty: short-note difficulty of 4K, 5K and 8K-10K charts on the MSD scale, a port of calc/rizu_difficulty.py.
---It runs rizucalc's engine with parameters tuned against MinaCalc (4K, 5K) and Prism (8K) by calc/tune_msd.py,
---and maps the raw rating linearly onto their scale. 9K and 10K are tuned against SRR, bridged onto the 7K scale.
---7K+1 is on the 7K+1 BMS table level scale of calc/tune_7k1s.py: 1..12 are Starlight sr1..sr12, 13..25 Satellite
---sl0..sl12 and 26..38 Stella st0..st12. 7K rates as 7K+1 with an empty scratch, 6K also without the middle key.
---14K+2 is on its own scale, the IIDX DP levels and DP tables of calc/tune_14k.py: 1..12 are IIDX levels, 13..23 are
---DP sl0..sl10 and 24..30 are DP st0..st6. 11K-14K rate as 14K+2 without scratches, 15K-18K as 18K+2 and 19K-36K as 36K+2 (14K+2 upscaled by Automap, same scale), 3K as the first three 4K
---columns, and 2K as 4K with each key's notes alternating between two fingers.
---That short-note rating reads long notes as taps and is the "rice" value. The LN level ("ln", calc/ln_difficulty.py,
---through chart.scoring.rizucalc_ln) is the work long notes add, tuned against mania-tracker's headline on 4K charts
---and the same charts under FullLongNote 3, and against the BMS LN table (◆) on 7K+1, which 6K and 7K share. The
---other keymodes take the older 7K LN level, tuned against mania-tracker on the MSD scale. The headline joins the two as a power sum, and is the short-note
---rating for charts without long notes.
---@class rizu.library.RizuDifficulty: rizu.library.Calculator
local RizuDifficulty = {name = "rizu", version = 11, keys = {"rice", "ln"}}

---@param a number
---@param b number
---@return fun(raw: number): number
local function linear(a, b)
	return function(raw)
		return raw > 0 and math.max(a * raw + b, 0) or 0
	end
end

---@param a number
---@param b number
---@return fun(raw: number): number
local function sqrt_linear(a, b)
	return function(raw)
		return raw > 0 and math.max(a * math.sqrt(raw) + b, 0) or 0
	end
end

---Piecewise linear through the knots (xs[i], ys[i]), extended with the outer slopes.
---@param xs number[]
---@param ys number[]
---@return fun(raw: number): number
local function piecewise(xs, ys)
	return function(raw)
		if raw <= 0 then
			return 0
		end
		local i = 1
		while i < #xs - 1 and raw > xs[i + 1] do
			i = i + 1
		end
		return math.max(ys[i] + (raw - xs[i]) * (ys[i + 1] - ys[i]) / (xs[i + 1] - xs[i]), 0)
	end
end

-- Printed by `python3 -m calc.rizu_difficulty`; groups and cross are calc/rizucalc.py's LAYOUTS.
---@type {[string]: chart.scoring.rizucalc.Layout}
RizuDifficulty.layouts = {
	["4key"] = {
		groups = {1, 1, 2, 2},
		cross = {0.125, 0.125, 0.125},
		params = {window = 1, min_dt = 0.08, chord = 0, jack = 1.5, tech = 0.05, bins = 24, max_dt = 0.25, power = 8, tau = 2, stamina = 0.3, long_tau = 480, long_stamina = 0.1, reference_nps = 20, speed_exp = 1, pattern = 0, cross = 2, anchor = 0.25, density = 1.5, short_notes = 30, group_power = 2, delay = 0.03, bracket = 0, roll = 0},
		map = linear(0.769675, 2.58084),
	},
	-- D F thumb J K
	["5key"] = {
		groups = {1, 1, 3, 2, 2},
		cross = {0.25, 0.225, 0.225, 0.25},
		params = {window = 1, min_dt = 0.08, chord = 0.75, jack = 0, tech = 0, bins = 24, max_dt = 0.5, power = 6, tau = 1, stamina = 1, long_tau = 480, long_stamina = 0.1, reference_nps = 20, speed_exp = 0.5, pattern = 0.1, cross = 4, anchor = 0.25, density = 0.5, short_notes = 30, group_power = 4, delay = 0, bracket = 0, roll = 0},
		map = linear(1.200694, -0.025125),
	},
	-- scratch, S D F, thumb, J K L: the scratch is on the left hand
	["7key1scratch"] = {
		groups = {1, 1, 1, 1, 3, 2, 2, 2},
		cross = {0.35, 0.35, 0.25, 0.225, 0.225, 0.25, 0.35},
		params = {window = 0.5, min_dt = 0.1, chord = 0, jack = 0, tech = 0.05, bins = 24, max_dt = 0.25, power = 6, tau = 1, stamina = 2, long_tau = 60, long_stamina = 0.1, reference_nps = 20, speed_exp = 0.7, pattern = 0, cross = 0, anchor = 0.5, density = 1.5, short_notes = 240, group_power = 1, delay = 0.015, bracket = -0.5, roll = 0.45},
		map = piecewise({0.424166, 3.302002, 6.716558, 10.2723, 12.893843, 16.638927, 22.821554}, {1.255567, 7.179715, 13.149986, 18.864976, 25.660804, 31.190922, 36.673135}),
	},
	["8key"] = {
		groups = {1, 1, 1, 1, 2, 2, 2, 2},
		cross = {0.45, 0.35, 0.25, 0.05, 0.25, 0.35, 0.45},
		params = {window = 0.25, min_dt = 0.06, chord = -0.5, jack = 1, tech = 0, bins = 24, max_dt = 0.5, power = 4, tau = 1, stamina = 2, long_tau = 240, long_stamina = 0, reference_nps = 20, speed_exp = 0.7, pattern = 0, cross = 4, anchor = 0.25, density = 0.5, short_notes = 0, group_power = 8, delay = 0, bracket = 0, roll = 0},
		map = linear(0.384708, -0.506417),
	},
	-- two hands of four and the middle key as a thumb group, like 7K
	["9key"] = {
		groups = {1, 1, 1, 1, 3, 2, 2, 2, 2},
		cross = {0.45, 0.35, 0.25, 0.275, 0.275, 0.25, 0.35, 0.45},
		params = {window = 1, min_dt = 0.12, chord = -0.5, jack = 0, tech = 0.05, bins = 6, max_dt = 1.0, power = 4, tau = 1, stamina = 2, long_tau = 480, long_stamina = 0, reference_nps = 20, speed_exp = 0.85, pattern = 0.1, cross = 4, anchor = 0.5, density = 1.5, short_notes = 30, group_power = 4, delay = 0.045, bracket = 0.25, roll = 0},
		map = linear(0.419967, 0.385109),
	},
	["10key"] = {
		groups = {1, 1, 1, 1, 1, 2, 2, 2, 2, 2},
		cross = {0.55, 0.45, 0.35, 0.25, 0.05, 0.25, 0.35, 0.45, 0.55},
		params = {window = 1, min_dt = 0.08, chord = 0, jack = 0, tech = 0, bins = 24, max_dt = 0.5, power = 6, tau = 1, stamina = 2, long_tau = 240, long_stamina = 0, reference_nps = 20, speed_exp = 0.7, pattern = 0, cross = 4, anchor = 0, density = 0.5, short_notes = 30, group_power = 4, delay = 0.06, bracket = 0.5, roll = 0},
		map = linear(0.502956, 1.80104),
	},
	-- one hand per side: key1-key7 and scratch1, key8-key14 and scratch2
	["14key2scratch"] = {
		groups = {1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 1, 2},
		cross = {1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 0, 0},
		params = {window = 4, min_dt = 0.04, chord = 0.75, jack = 0.5, tech = 0, bins = 24, max_dt = 0.5, power = 4, tau = 10, stamina = 5, long_tau = 480, long_stamina = 0.8, reference_nps = 20, speed_exp = 0.7, pattern = 1, cross = 0.25, anchor = 0, density = 1, short_notes = 240, group_power = 16, delay = 0, bracket = 0, roll = 0},
		map = sqrt_linear(1.294339, -0.152478),
	},
}

---A DP layout: keys / 2 keys per side, then scratch1 and scratch2, one hand per side.
---@param keys integer
---@param params chart.scoring.rizucalc.Params
---@param map fun(raw: number): number
---@return chart.scoring.rizucalc.Layout
local function dp_layout(keys, params, map)
	local half = math.floor(keys / 2)
	---@type integer[], number[]
	local groups, cross = {}, {}
	for i = 1, keys do
		groups[i] = i <= half and 1 or 2
		cross[i] = (i == half or i == keys) and 0 or 1
	end
	groups[keys + 1], groups[keys + 2] = 1, 2
	cross[keys + 1] = 0
	return {groups = groups, cross = cross, params = params, map = map}
end

-- 14K+2 upscaled by Automap, calc/tune_14k.py with the caches 14key2scratch_am18 and _am36
RizuDifficulty.layouts["18key2scratch"] = dp_layout(18, {window = 8, min_dt = 0.05, chord = 1, jack = 0.5, tech = 0.05, bins = 24, max_dt = 0.5, power = 4, tau = 5, stamina = 5, long_tau = 480, long_stamina = 1.6, reference_nps = 20, speed_exp = 1, pattern = 1, cross = 0, anchor = 0, density = 1, short_notes = 240, group_power = 4, delay = 0, bracket = 0, roll = 0}, sqrt_linear(0.831409, 1.247408))
RizuDifficulty.layouts["36key2scratch"] = dp_layout(36, {window = 8, min_dt = 0.05, chord = 1, jack = 0.5, tech = 0, bins = 24, max_dt = 0.5, power = 4, tau = 2, stamina = 5, long_tau = 960, long_stamina = 0.8, reference_nps = 20, speed_exp = 1, pattern = 2, cross = 0, anchor = 0, density = 1, short_notes = 240, group_power = 4, delay = 0, bracket = 0, roll = 0}, sqrt_linear(0.648829, 1.025547))

-- Printed by `python3 -m calc.ln_difficulty`: the LN level's parameters, calc/ln_difficulty.py's PARAMS and SCALES.
---@type {[string]: chart.scoring.rizucalc_ln.Params}
RizuDifficulty.ln = {
	["4key"] = {min_hold = 0.1, held = 0.5, repress = 0.5, repress_window = 0.5, window = 0.25, group_power = 2, power = 1, curve = 0.35, combine = 2, long_release = 0, long_full = 0.7, scale = 10.810477},
	["7key1scratch"] = {min_hold = 0.08, held = 2, repress = 0, repress_window = 0.2, window = 0.15, group_power = 32, power = 6, curve = 0.7, combine = 3, long_release = 1, long_full = 0.3, scale = 1.397745},
	["7key"] = {min_hold = 0.2, held = 4, repress = 0, repress_window = 0.2, window = 0.25, group_power = 16, power = 4, curve = 0.7, combine = 3, long_release = 1, long_full = 0.7, scale = 2.102133},
}

-- shortcut: only 4K, 7K+1 (with 6K and 7K) and the MSD-scale 7K LN are tuned, 3K and 2K take 4K's below and every
-- other keymode the MSD-scale 7K's; tune one if people play LN in it
for inputmode, layout in pairs(RizuDifficulty.layouts) do
	layout.ln = RizuDifficulty.ln[inputmode] or RizuDifficulty.ln["7key"]
end

---A layout that rates its keymode as another one, through the columns its notes go to.
---@param layout chart.scoring.rizucalc.Layout
---@param columns integer[][]
---@return chart.scoring.rizucalc.Layout
local function mapped(layout, columns)
	return {groups = layout.groups, cross = layout.cross, params = layout.params, map = layout.map, ln = layout.ln, columns = columns}
end

local layout_7k1s = RizuDifficulty.layouts["7key1scratch"]
-- scratch1 is 7K+1's last column and the layout's first
layout_7k1s.columns = {{2}, {3}, {4}, {5}, {6}, {7}, {8}, {1}}
RizuDifficulty.layouts["7key"] = mapped(layout_7k1s, {{2}, {3}, {4}, {5}, {6}, {7}, {8}})
-- 6K is 7K without the middle key
RizuDifficulty.layouts["6key"] = mapped(layout_7k1s, {{2}, {3}, {4}, {6}, {7}, {8}})

-- 3K on the first three 4K columns
RizuDifficulty.layouts["3key"] = mapped(RizuDifficulty.layouts["4key"], {{1}, {2}, {3}})
-- 2K is played as 4K with two fingers per key in turn
RizuDifficulty.layouts["2key"] = mapped(RizuDifficulty.layouts["4key"], {{1, 2}, {3, 4}})
-- 11K-14K on the 14K+2 keys without scratches, 15K-18K on 18K+2 and 19K-36K on 36K+2: the left half, the larger one,
-- from the first key, the right half from the layout's middle
for keys = 11, 36 do
	local target = keys <= 14 and 14 or keys <= 18 and 18 or 36
	---@type integer[][]
	local columns = {}
	local left = math.ceil(keys / 2)
	for i = 1, keys do
		columns[i] = {i <= left and i or i - left + target / 2}
	end
	RizuDifficulty.layouts[keys .. "key"] = mapped(RizuDifficulty.layouts[target .. "key2scratch"], columns)
end

---Rizu Difficulty of notes sorted by time then column, its short-note rating and its LN level, or nil for keymodes it
---doesn't rate.
---@param notes {time: number, column: integer, input: chart.Column?, end_time: number?}[]
---@param inputmode string
---@return number?
---@return number?
---@return number?
function RizuDifficulty.rate(notes, inputmode)
	local layout = RizuDifficulty.layouts[inputmode]
	if not layout then
		return
	end
	---@type number[], integer[], {[integer]: number}
	local times, cols, ends = {}, {}, {}
	---@type {[integer]: integer}
	local turn = {}
	for _, note in ipairs(notes) do
		local col = note.column
		local targets = layout.columns and layout.columns[col]
		if targets then
			turn[col] = (turn[col] or 0) % #targets + 1
			col = targets[turn[col]]
		end
		table.insert(times, note.time)
		table.insert(cols, col)
		ends[#times] = note.end_time
	end
	local rice = layout.map(rizucalc.rate(times, cols, layout))
	local p = assert(layout.ln, "layout without LN parameters")
	local raw = rizucalc_ln.raw(times, cols, ends, layout.groups, p)
	if raw == 0 then
		return rice, rice, 0
	end
	local ln = p.scale * raw ^ p.curve
	return (rice ^ p.combine + ln ^ p.combine) ^ (1 / p.combine), rice, ln
end

-- Printed by `python3 -m calc.tune_dan dans`: the 4K rating at REFORM dans 0 (intro 3rd) to 18 (theta), fitted on
-- players' dan labels of short-note charts.
-- shortcut: under 10 labelled charts per dan below 3rd and above zeta, refit when players send more labels
RizuDifficulty.dans_4k = {12.85, 14.12, 15.12, 16.88, 18.05, 19.73, 20.75, 23.35, 23.56, 24.48, 24.9, 27.09, 27.89, 29.54, 31.63, 35.51, 38.49, 42.49, 46.04}

-- The 7K rating at the four-chart averages of Jinjin's Regular Dan courses, 0th (intro) to Zenith. Found by rating each chart of
-- the courses apart (split at the 3 longest breaks) and taking the mean per course.
-- shortcut: one mapper's course set, not player labels; refit on labelled 7K charts when there are some
RizuDifficulty.dans_7k = {11.01, 13.1, 14.94, 16.62, 17.11, 18.21, 20.87, 22.45, 24.27, 25.6, 27.56, 29.89, 31.94, 33.88}

---Knots and names of the dans a keymode shows. The first knot is dan 0, below the first name.
---@type {[string]: {knots: number[], names: string[]}}
RizuDifficulty.dan_tables = {
	["4key"] = {knots = RizuDifficulty.dans_4k, names = {"1st", "2nd", "3rd", "4th", "5th", "6th", "7th", "8th", "9th", "10th",
		"Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta", "Eta", "Theta"}},
	["7key"] = {knots = RizuDifficulty.dans_7k, names = {"1st", "2nd", "3rd", "4th", "5th", "6th", "7th", "8th", "9th", "10th",
		"Gamma", "Azimuth", "Zenith"}},
}

---The dan nearest to a short-note rating, with "-" or "+" in its lower or upper third: "Intro" below 1st dan, "Theta+"
---past the last one. Thirds match the fit's ~0.3 dan error, so neighbors read as "Beta+" and "Gamma-". Nil for
---keymodes without dans.
---@param rating number
---@param inputmode string? default "4key", the REFORM dans
---@return string?
function RizuDifficulty.dan(rating, inputmode)
	local dans = RizuDifficulty.dan_tables[inputmode or "4key"]
	if not dans then
		return
	end
	local knots, names = dans.knots, dans.names
	local i = 2
	while i < #knots and rating > knots[i] do
		i = i + 1
	end
	-- dans 0.. sit at knots 1..; outside them the nearest segment's slope carries on
	local dan = i - 2 + (rating - knots[i - 1]) / (knots[i] - knots[i - 1])
	local d = math.floor(dan + 0.5)
	if d < 1 then
		return "Intro"
	elseif d > #names then
		return names[#names] .. "+"
	end
	local third = dan - d
	return names[d] .. (third < -1 / 6 and "-" or third > 1 / 6 and "+" or "")
end

---@param ctx chart.DiffcalcContext
---@return rizu.library.Calculators.Result
function RizuDifficulty:compute(ctx)
	local total, rice, ln = RizuDifficulty.rate(ctx:getSimplifiedNotes(), tostring(ctx.chart.inputMode))
	if not total then
		return
	end
	return {[0] = total, rice = rice, ln = ln}
end

return RizuDifficulty
