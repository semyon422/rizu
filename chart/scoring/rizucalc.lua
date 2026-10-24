-- Port of the calc/ difficulty calculators (calc/README.md): v2 4K, v2 7K and v1 14K.
-- Ratings are on the 4K scale (v2 4K mapped onto MSD) for 4key, 7key and 7key1scratch,
-- and on the IIDX DP level scale for 14key2scratch.

local bit = require("bit")

local rizucalc = {}

local RECOVERY_TAU = 5 / math.log(10) -- exp(-5 / tau) = 0.1

---@class chart.scoring.rizucalc.Params
---@field window number seconds
---@field min_dt number clamp, seconds
---@field chord number group row strain multiplier is size^chord
---@field jack number weight of 1/column_dt
---@field tech number window multiplier per nat of row delta entropy
---@field bins number row delta quantization, bins per octave
---@field max_dt number longer row deltas are breaks, not rhythm
---@field power number power mean over windows
---@field tau number short-term fatigue, seconds
---@field stamina number difficulty multiplier per reference_nps of short-term fatigue
---@field long_tau number seconds for long-term fatigue to build up
---@field long_stamina number
---@field reference_nps number
---@field speed_exp number group speed is (1/row_dt)^speed_exp
---@field pattern number window multiplier per nat of row mask entropy
---@field cross number weight of neighbor column alternation
---@field anchor number weight of uneven column use
---@field density number windows weigh into the power mean by their note count to this exponent
---@field short_notes number the rating is multiplied by n / (n + short_notes)
---@field group_power number power mean of group speeds

---@class chart.scoring.rizucalc.Layout
---@field params chart.scoring.rizucalc.Params
---@field groups integer[] group of each column
---@field cross number[] cross[i] is the weight of columns i and i + 1
---@field skip_input string? input dropped before rating
---@field map fun(raw: number): number raw rating to user_diff

---@type chart.scoring.rizucalc.Params
local params_4k = {
	window = 0.25, min_dt = 0.06, chord = 0, jack = 1.5, tech = 0.05, bins = 24, max_dt = 0.25, power = 6,
	tau = 5, stamina = 0.3, long_tau = 120, long_stamina = 0.2, reference_nps = 20,
	speed_exp = 1, pattern = 0, cross = 0.25, anchor = 0.25, density = 1, short_notes = 0, group_power = 2,
}

---@type chart.scoring.rizucalc.Params
local params_7k = {
	window = 1, min_dt = 0.03, chord = 0.5, jack = 1.5, tech = 0.05, bins = 24, max_dt = 0.5, power = 6,
	tau = 1, stamina = 2, long_tau = 60, long_stamina = 0.2, reference_nps = 20,
	speed_exp = 0.5, pattern = 0.2, cross = 1, anchor = 0.5, density = 0.5, short_notes = 240, group_power = 2,
}

---@type chart.scoring.rizucalc.Params
local params_14k = {
	window = 4, min_dt = 0.04, chord = 0.75, jack = 0.5, tech = 0, bins = 24, max_dt = 0.5, power = 4,
	tau = 10, stamina = 5, long_tau = 480, long_stamina = 0.8, reference_nps = 20,
	speed_exp = 0.7, pattern = 1, cross = 0.25, anchor = 0, density = 1, short_notes = 240, group_power = 16,
}

-- linear fit of v2 4K on MSD 17-31
local function map_4k(raw)
	return raw > 0 and 0.67977701 * raw + 6.78613977 or 0
end

-- (v2 7K, 4K scale) of 7K and 4K dans that feel alike (calc/write_user_diff.py DANS_7K_TO_4K)
local dans_7k_to_4k = {{24.71, 17.08}, {49.09, 22.87}, {68.34, 25.05}, {94.05, 27.76}, {123.30, 32.27}}

-- piecewise linear in ln(v2 7K) through the dans, extended with the outer slopes (calc/write_user_diff.py dan_curve)
local function map_7k(raw)
	local x = math.log(math.max(raw, 1e-9))
	local d = dans_7k_to_4k
	local i = 1
	while i < #d - 1 and x > math.log(d[i + 1][1]) do
		i = i + 1
	end
	local x0, x1 = math.log(d[i][1]), math.log(d[i + 1][1])
	local y0, y1 = d[i][2], d[i + 1][2]
	return math.max(y0 + (x - x0) * (y1 - y0) / (x1 - x0), 0)
end

-- fit of IIDX DP levels and DP tables (calc/tune_14k.py)
local function map_14k(raw)
	return math.max(1.25991768 * math.sqrt(raw) - 0.02181418, 0)
end

-- left hand, right hand, middle key as its own thumb group
local groups_7k = {1, 1, 1, 3, 2, 2, 2}
-- SRR's 7K finger pair weights
local cross_7k = {0.35, 0.25, 0.225, 0.225, 0.25, 0.35}

---@type {[string]: chart.scoring.rizucalc.Layout}
rizucalc.layouts = {
	["4key"] = {params = params_4k, groups = {1, 1, 2, 2}, cross = {0.125, 0.125, 0.125}, map = map_4k},
	["7key"] = {params = params_7k, groups = groups_7k, cross = cross_7k, map = map_7k},
	-- keyboard players play these without the scratch
	["7key1scratch"] = {params = params_7k, groups = groups_7k, cross = cross_7k, skip_input = "scratch1", map = map_7k},
	-- one hand per side: key1-key7 and scratch1, key8-key14 and scratch2
	["14key2scratch"] = {
		params = params_14k,
		groups = {1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 1, 2},
		cross = {1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 0, 0},
		map = map_14k,
	},
}

---@param counts {[integer]: integer}
---@param total integer
---@return number
local function entropy(counts, total)
	local h = 0
	for _, c in pairs(counts) do
		local p = c / total
		h = h - p * math.log(p)
	end
	return h
end

--- Shannon entropy (nats) of values inside each window; ws must be nondecreasing.
---@param ws integer[]
---@param values integer[]
---@param nw integer
---@return number[]
local function window_entropy(ws, values, nw)
	---@type number[]
	local out = {}
	for w = 1, nw do
		out[w] = 0
	end
	---@type {[integer]: integer}, integer, integer?
	local counts, total, cur = {}, 0, nil
	for i = 1, #ws do
		local w = ws[i]
		if w ~= cur then
			if cur then
				out[cur] = entropy(counts, total)
			end
			counts, total, cur = {}, 0, w
		end
		counts[values[i]] = (counts[values[i]] or 0) + 1
		total = total + 1
	end
	if cur then
		out[cur] = entropy(counts, total)
	end
	return out
end

--- Fatigue per window, moving toward the window's notes per second with separate rise and fall time constants.
---@param nps number[]
---@param window number
---@param tau_up number
---@param tau_down number
---@return number[]
local function fatigue(nps, window, tau_up, tau_down)
	local up, down = 1 - math.exp(-window / tau_up), 1 - math.exp(-window / tau_down)
	---@type number[]
	local f = {}
	local acc = 0
	for i, x in ipairs(nps) do
		acc = acc + (x - acc) * (x > acc and up or down)
		f[i] = acc
	end
	return f
end

--- SRR's anchor transform of the note counts per column in a window: above 0 when one column carries more notes.
---@param counts integer[]
---@return number
local function anchor(counts)
	---@type integer[]
	local c = {}
	for i, v in ipairs(counts) do
		c[i] = v
	end
	table.sort(c, function(a, b) return a > b end)
	local walk, total = 0, 0
	for k = 1, #c - 1 do
		local hi, lo = c[k], c[k + 1]
		if lo > 0 then
			local ratio = lo / hi
			walk = walk + hi * (1 - 4 * (0.5 - ratio) ^ 2)
			total = total + hi
		end
	end
	if total == 0 then
		return 0
	end
	local a = walk / total
	return math.min(a - 0.18, 5 * (a - 0.22) ^ 3)
end

--- Rounds half to even, like numpy, so ratings match calc/ exactly.
---@param x number
---@return integer
local function round(x)
	local f = math.floor(x)
	local d = x - f
	if d > 0.5 or d == 0.5 and f % 2 == 1 then
		return f + 1
	end
	return f
end

--- Times in integer ms, with notes closer than 3 ms to the previous row moved onto that row.
---@param times number[] sorted, seconds
---@return integer[]
local function snap_ms(times)
	---@type integer[]
	local ms = {}
	---@type integer?, integer
	local prev, row
	for i, t in ipairs(times) do
		local m = round(t * 1000)
		if m ~= prev then
			if not prev or m - prev >= 3 then
				row = m
			end
			prev = m
		end
		ms[i] = row
	end
	return ms
end

--- Raw rating of notes sorted by time then column.
---@param times number[] seconds
---@param cols integer[] 1-based
---@param layout chart.scoring.rizucalc.Layout
---@return number
function rizucalc.rate(times, cols, layout)
	local n = #times
	if n == 0 then
		return 0
	end
	local p = layout.params
	local groups, cross = layout.groups, layout.cross
	local keys = #groups
	local ng = 0
	for _, g in ipairs(groups) do
		ng = math.max(ng, g)
	end

	local ms = snap_ms(times)
	local t0 = ms[1] / 1000
	local window = p.window

	-- notes of a group at the same millisecond form one row; row strain needs the row size, so rows come first
	---@type integer[], integer[]
	local row_of, row_size = {}, {}
	---@type {[integer]: integer[]} group -> {ms, row}
	local last_row = {}
	local nrows = 0
	for i = 1, n do
		local g = groups[cols[i]]
		local r = last_row[g]
		if r and r[1] == ms[i] then
			row_of[i] = r[2]
			row_size[r[2]] = row_size[r[2]] + 1
		else
			nrows = nrows + 1
			last_row[g] = {ms[i], nrows}
			row_of[i] = nrows
			row_size[nrows] = 1
		end
	end

	---@type number[], number[]
	local strain, row_strain = {}, {}
	---@type {[integer]: integer} group -> ms of its previous row
	local group_prev = {}
	---@type {[integer]: integer}
	local col_prev = {}
	---@type {[integer]: integer}, {[integer]: number}
	local pair_ms, pair_dt = {}, {}
	for i = 1, n do
		local m, c, r = ms[i], cols[i], row_of[i]
		local g = groups[c]
		if not row_strain[r] then
			local prev = group_prev[g]
			local dt = prev and m / 1000 - prev / 1000 or math.huge
			row_strain[r] = row_size[r] ^ p.chord / math.max(dt, p.min_dt) ^ p.speed_exp
			group_prev[g] = m
		end
		local cprev = col_prev[c]
		local col_dt = cprev and m / 1000 - cprev / 1000 or math.huge
		col_prev[c] = m
		local s = row_strain[r] + p.jack / math.max(col_dt, p.min_dt)
		if p.cross ~= 0 then
			for j = c - 1, c do
				local coeff = cross[j]
				if coeff then
					if pair_ms[j] ~= m then
						pair_dt[j] = pair_ms[j] and (m - pair_ms[j]) / 1000 or math.huge
						pair_ms[j] = m
					end
					s = s + p.cross * coeff / math.max(pair_dt[j], p.min_dt) ^ p.speed_exp
				end
			end
		end
		strain[i] = s
	end

	---@type integer[]
	local w = {}
	for i = 1, n do
		w[i] = math.floor((ms[i] / 1000 - t0) / window) + 1
	end
	local nw = w[n]

	---@type number[][], integer[][], integer[], integer[][]
	local sum, cnt, count, col_counts = {}, {}, {}, {}
	for k = 1, nw do
		sum[k], cnt[k], count[k] = {}, {}, 0
		for g = 1, ng do
			sum[k][g], cnt[k][g] = 0, 0
		end
		if p.anchor ~= 0 then
			col_counts[k] = {}
			for c = 1, keys do
				col_counts[k][c] = 0
			end
		end
	end
	for i = 1, n do
		local k, g = w[i], groups[cols[i]]
		sum[k][g] = sum[k][g] + strain[i]
		cnt[k][g] = cnt[k][g] + 1
		count[k] = count[k] + 1
		if p.anchor ~= 0 then
			col_counts[k][cols[i]] = col_counts[k][cols[i]] + 1
		end
	end

	-- rhythm variety: quantized deltas between rows; pattern variety: which columns each row uses
	---@type integer[], integer[], integer[], integer[]
	local tech_w, tech_q, mask_w, masks = {}, {}, {}, {}
	---@type integer?
	local prev_ms
	for i = 1, n do
		local m = ms[i]
		if m ~= prev_ms then
			local k = math.floor((m / 1000 - t0) / window) + 1
			if prev_ms then
				local d = (m - prev_ms) / 1000
				if d <= p.max_dt then
					table.insert(tech_w, k)
					table.insert(tech_q, round(math.log(d) / math.log(2) * p.bins))
				end
			end
			table.insert(mask_w, k)
			table.insert(masks, 0)
			prev_ms = m
		end
		masks[#masks] = bit.bor(masks[#masks], bit.lshift(1, cols[i] - 1))
	end
	local tech = window_entropy(tech_w, tech_q, nw)
	local pattern = window_entropy(mask_w, masks, nw)

	---@type number[]
	local nps = {}
	for k = 1, nw do
		nps[k] = count[k] / window
	end
	local short = fatigue(nps, window, p.tau, p.tau)
	local long = fatigue(nps, window, p.long_tau, RECOVERY_TAU)

	---@type number, number
	local num, den = 0, 0
	for k = 1, nw do
		---@type number
		local group_sum = 0
		for g = 1, ng do
			local mean = cnt[k][g] > 0 and sum[k][g] / cnt[k][g] or 0
			group_sum = group_sum + mean ^ p.group_power
		end
		---@type number
		local speed = (group_sum / ng) ^ (1 / p.group_power)
		---@type number
		local diff = speed * (1 + p.tech * tech[k] + p.pattern * pattern[k])
		if p.anchor ~= 0 then
			diff = diff * math.max(1 + p.anchor * anchor(col_counts[k]), 0)
		end
		diff = diff * (1 + p.stamina * short[k] / p.reference_nps) * (1 + p.long_stamina * long[k] / p.reference_nps)
		if diff > 0 then
			local weight = count[k] ^ p.density
			num = num + weight * diff ^ p.power
			den = den + weight
		end
	end
	if den == 0 then -- a single row has no deltas
		return 0
	end
	return (num / den) ^ (1 / p.power) * n / (n + p.short_notes)
end

--- user_diff of simplified notes, nil for inputmodes without a calculator.
---@param notes {time: number, column: integer, input: chart.Column}[] sorted by time then column
---@param inputmode string
---@param rate number
---@return number?
function rizucalc.calc(notes, inputmode, rate)
	local layout = rizucalc.layouts[inputmode]
	if not layout then
		return
	end
	local times, cols = {}, {}
	for _, note in ipairs(notes) do
		if note.input ~= layout.skip_input then
			table.insert(times, note.time / rate)
			table.insert(cols, note.column)
		end
	end
	return layout.map(rizucalc.rate(times, cols, layout))
end

return rizucalc
