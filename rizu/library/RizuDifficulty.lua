local rizucalc = require("chart.scoring.rizucalc")

---Rizu Difficulty: short-note difficulty of 4K-10K and 7K+1 charts on the MSD scale, a port of calc/rizu_difficulty.py.
---It runs rizucalc's engine with parameters tuned against MinaCalc (4K, 5K) and Prism (6K-8K) by calc/tune_msd.py,
---and maps the raw rating linearly onto their scale. 9K and 10K are tuned against SRR, bridged onto the 7K scale.
---14K+2 is on its own scale, the IIDX DP levels and DP tables of calc/tune_14k.py: 1..12 are IIDX levels, 13..23 are
---DP sl0..sl10 and 24..30 are DP st0..st6. 11K-14K rate as 14K+2 without scratches, 3K as the first three 4K
---columns, and 2K as 4K with each key's notes alternating between two fingers.
---Hold ends are ignored: long notes rate as taps.
---@class rizu.library.RizuDifficulty: rizu.library.Calculator
local RizuDifficulty = {name = "rizu", version = 6}

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

-- Printed by `python3 -m calc.rizu_difficulty`; groups and cross are calc/rizucalc.py's LAYOUTS.
---@type {[string]: chart.scoring.rizucalc.Layout}
RizuDifficulty.layouts = {
	["4key"] = {
		groups = {1, 1, 2, 2},
		cross = {0.125, 0.125, 0.125},
		params = {window = 0.5, min_dt = 0.08, chord = -0.5, jack = 1.5, tech = 0.05, bins = 12, max_dt = 0.25, power = 6, tau = 20, stamina = 0.3, long_tau = 1920, long_stamina = 0.1, reference_nps = 20, speed_exp = 1, pattern = 0, cross = 0.5, anchor = 0.25, density = 1, short_notes = 30, group_power = 1, delay = 0.03, bracket = 0, roll = 0},
		map = linear(1.052435, 1.647323),
	},
	-- D F thumb J K
	["5key"] = {
		groups = {1, 1, 3, 2, 2},
		cross = {0.25, 0.225, 0.225, 0.25},
		params = {window = 1, min_dt = 0.08, chord = 0.75, jack = 0, tech = 0, bins = 24, max_dt = 0.5, power = 6, tau = 1, stamina = 1, long_tau = 480, long_stamina = 0.1, reference_nps = 20, speed_exp = 0.5, pattern = 0.1, cross = 4, anchor = 0.25, density = 0.5, short_notes = 30, group_power = 4, delay = 0, bracket = 0, roll = 0},
		map = linear(1.200694, -0.025125),
	},
	["6key"] = {
		groups = {1, 1, 1, 2, 2, 2},
		cross = {0.35, 0.25, 0.05, 0.25, 0.35},
		params = {window = 0.25, min_dt = 0.06, chord = -0.5, jack = 1, tech = 0, bins = 24, max_dt = 0.5, power = 4, tau = 1, stamina = 2, long_tau = 240, long_stamina = 0, reference_nps = 20, speed_exp = 0.7, pattern = 0, cross = 4, anchor = 0.25, density = 0.5, short_notes = 0, group_power = 8, delay = 0, bracket = 0, roll = 0},
		map = linear(0.454744, 1.314084),
	},
	-- S D F, J K L, and the middle key as a thumb group
	["7key"] = {
		groups = {1, 1, 1, 3, 2, 2, 2},
		cross = {0.35, 0.25, 0.225, 0.225, 0.25, 0.35},
		params = {window = 0.5, min_dt = 0.06, chord = -0.25, jack = 0, tech = 0, bins = 24, max_dt = 0.5, power = 6, tau = 1, stamina = 2, long_tau = 960, long_stamina = 0.1, reference_nps = 20, speed_exp = 0.5, pattern = 0, cross = 0.5, anchor = 1, density = 1, short_notes = 30, group_power = 1, delay = 0, bracket = -0.2, roll = 0.3},
		map = linear(2.49105, -0.525028),
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

local layout_7k = RizuDifficulty.layouts["7key"]
-- keyboard players play 7K+1 charts without the scratch
RizuDifficulty.layouts["7key1scratch"] = {
	groups = layout_7k.groups,
	cross = layout_7k.cross,
	params = layout_7k.params,
	map = layout_7k.map,
	skip_input = "scratch1",
}

---A layout that rates its keymode as another one, through the columns its notes go to.
---@param layout chart.scoring.rizucalc.Layout
---@param columns integer[][]
---@return chart.scoring.rizucalc.Layout
local function mapped(layout, columns)
	return {groups = layout.groups, cross = layout.cross, params = layout.params, map = layout.map, columns = columns}
end

-- 3K on the first three 4K columns
RizuDifficulty.layouts["3key"] = mapped(RizuDifficulty.layouts["4key"], {{1}, {2}, {3}})
-- 2K is played as 4K with two fingers per key in turn
RizuDifficulty.layouts["2key"] = mapped(RizuDifficulty.layouts["4key"], {{1, 2}, {3, 4}})
-- 11K-14K on the 14K+2 keys without scratches: the left half, the larger one, from key1, the right half from key8
for keys = 11, 14 do
	---@type integer[][]
	local columns = {}
	local left = math.ceil(keys / 2)
	for i = 1, keys do
		columns[i] = {i <= left and i or i - left + 7}
	end
	RizuDifficulty.layouts[keys .. "key"] = mapped(RizuDifficulty.layouts["14key2scratch"], columns)
end

---Rizu Difficulty of notes sorted by time then column, or nil for keymodes it doesn't rate.
---@param notes {time: number, column: integer, input: chart.Column?}[]
---@param inputmode string
---@return number?
function RizuDifficulty.rate(notes, inputmode)
	local layout = RizuDifficulty.layouts[inputmode]
	if not layout then
		return
	end
	---@type number[], integer[]
	local times, cols = {}, {}
	---@type {[integer]: integer}
	local turn = {}
	for _, note in ipairs(notes) do
		if not layout.skip_input or note.input ~= layout.skip_input then
			local col = note.column
			local targets = layout.columns and layout.columns[col]
			if targets then
				turn[col] = (turn[col] or 0) % #targets + 1
				col = targets[turn[col]]
			end
			table.insert(times, note.time)
			table.insert(cols, col)
		end
	end
	return layout.map(rizucalc.rate(times, cols, layout))
end

---@param ctx chart.DiffcalcContext
---@return number?
function RizuDifficulty:compute(ctx)
	return RizuDifficulty.rate(ctx:getSimplifiedNotes(), tostring(ctx.chart.inputMode))
end

return RizuDifficulty
