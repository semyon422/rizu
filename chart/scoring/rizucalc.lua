-- The engine of calc/rizucalc.py: a raw rating from a layout and its parameters. Rizu Difficulty
-- (rizu.library.RizuDifficulty) gives the layouts and maps the rating onto its scale.

local bit = require("bit")

local rizucalc = {}

local RECOVERY_TAU = 5 / math.log(10) -- exp(-5 / tau) = 0.1
local MOTION_MAX_DT = 0.25 -- seconds between the rows of a bracket or roll, Prism's MOTION_MAX_GAP_MS

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
---@field delay number seconds: a note this close to its group's row start joins that row
---@field bracket number group row strain multiplier is 1 + bracket for the last row of an A-B-A bracket
---@field roll number group row strain multiplier is 1 - roll for a one-finger step continuing a roll

---@class chart.scoring.rizucalc.Layout
---@field params chart.scoring.rizucalc.Params
---@field groups integer[] group of each column
---@field cross number[] cross[i] is the weight of columns i and i + 1
---@field skip_input string? input dropped before rating
---@field columns integer[][]? the notes of column i go to the columns columns[i], one after another in turn
---@field map fun(raw: number): number raw rating to the displayed one
---@field ln chart.scoring.rizucalc_ln.Params? the LN level's parameters, see rizu.library.RizuDifficulty

---@param counts {[integer]: number}
---@param total number
---@return number
local function entropy(counts, total)
	local h = 0
	for _, c in pairs(counts) do
		if c > 0 then
			local p = c / total
			h = h - p * math.log(p)
		end
	end
	return h
end

--- Shannon entropy (nats) of values inside each window, each value counted with its weight (default 1); ws must be
--- nondecreasing.
---@param ws integer[]
---@param values integer[]
---@param nw integer
---@param weights number[]?
---@return number[]
local function window_entropy(ws, values, nw, weights)
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
		local wt = weights and weights[i] or 1
		counts[values[i]] = (counts[values[i]] or 0) + wt
		total = total + wt
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

---@param x integer
---@return integer
local function popcount(x)
	local c = 0
	while x ~= 0 do
		c = c + bit.band(x, 1)
		x = bit.rshift(x, 1)
	end
	return c
end

--- Whether shapes a, b, c of one group's rows form a bracket like Prism's: b disjoint from a and c, c overlapping
--- a, and b and c using 3 or more fingers.
---@param a integer
---@param b integer
---@param c integer
---@return boolean
local function is_bracket(a, b, c)
	return bit.band(b, c) == 0 and bit.band(a, c) ~= 0 and bit.band(a, b) == 0 and popcount(bit.bor(b, c)) >= 3
end

--- 1 or -1 when shape b is one finger in the column after or before shape a's one finger, else 0.
---@param a integer
---@param b integer
---@return integer
local function step(a, b)
	if popcount(a) ~= 1 or popcount(b) ~= 1 then
		return 0
	elseif b == bit.lshift(a, 1) then
		return 1
	elseif b == bit.rshift(a, 1) then
		return -1
	end
	return 0
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

	-- notes of a group at the same millisecond, or up to delay after its row start, form one row; row strain
	-- needs the row size and shape, so rows come first
	local delay_ms = round(p.delay * 1000)
	---@type integer[], integer[], integer[]
	local row_of, row_size, row_mask = {}, {}, {}
	---@type {[integer]: integer[]} group -> {start ms, row}
	local last_row = {}
	local nrows = 0
	for i = 1, n do
		local g = groups[cols[i]]
		local r = last_row[g]
		if r and ms[i] - r[1] <= delay_ms then
			row_of[i] = r[2]
			row_size[r[2]] = row_size[r[2]] + 1
		else
			nrows = nrows + 1
			last_row[g] = {ms[i], nrows}
			row_of[i] = nrows
			row_size[nrows] = 1
			row_mask[nrows] = 0
		end
		row_mask[row_of[i]] = bit.bor(row_mask[row_of[i]], bit.lshift(1, cols[i] - 1))
	end

	---@type number[], number[]
	local strain, row_strain = {}, {}
	---@type {[integer]: integer} group -> ms of its previous row
	local group_prev = {}
	---@type {[integer]: integer}, {[integer]: integer} group -> its previous row and the one before
	local prev1, prev2 = {}, {}
	-- per row: 1 or -1 when it is a one-finger step to the next column from its group's previous row, else 0
	---@type integer[]
	local row_step = {}
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
			if p.bracket ~= 0 and prev2[g] and dt <= MOTION_MAX_DT and is_bracket(row_mask[prev2[g]], row_mask[prev1[g]], row_mask[r]) then
				row_strain[r] = row_strain[r] * (1 + p.bracket)
			end
			local r1 = prev1[g]
			row_step[r] = r1 and dt <= MOTION_MAX_DT and step(row_mask[r1], row_mask[r]) or 0
			if p.roll ~= 0 and row_step[r] ~= 0 and r1 and row_step[r1] == row_step[r] then
				row_strain[r] = row_strain[r] * (1 - p.roll)
			end
			group_prev[g] = m
			prev2[g], prev1[g] = prev1[g], r
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
	---@type integer[], integer[], number[], integer[], integer[]
	local tech_w, tech_q, tech_f, mask_w, masks = {}, {}, {}, {}, {}
	---@type integer?
	local prev_ms
	for i = 1, n do
		local m = ms[i]
		if m ~= prev_ms then
			local k = math.floor((m / 1000 - t0) / window) + 1
			if prev_ms then
				local d = (m - prev_ms) / 1000
				if d <= p.max_dt then
					-- a delta counts toward its two nearest bins by distance, so a rate change moves the entropy smoothly
					local x = math.log(d) / math.log(2) * p.bins
					local lo = math.floor(x)
					table.insert(tech_w, k)
					table.insert(tech_q, lo)
					table.insert(tech_f, 1 - (x - lo))
					table.insert(tech_w, k)
					table.insert(tech_q, lo + 1)
					table.insert(tech_f, x - lo)
				end
			end
			table.insert(mask_w, k)
			table.insert(masks, 0)
			prev_ms = m
		end
		masks[#masks] = bit.bor(masks[#masks], bit.lshift(1, cols[i] - 1))
	end
	local tech = window_entropy(tech_w, tech_q, nw, tech_f)
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

return rizucalc
