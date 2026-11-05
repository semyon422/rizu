-- The LN part of Rizu Difficulty, a port of calc/ln_difficulty.py: a raw rating from the work long notes add to a
-- chart, per hand group. rizu.library.RizuDifficulty gives the parameters and joins it with the short-note rating.

local rizucalc_ln = {}

local LN_MARGIN = 0.02 -- seconds: a press or release this close to another event happens together with it

---@class chart.scoring.rizucalc_ln.Params
---@field min_hold number seconds, shorter holds play like taps
---@field held number work of a press or release while another column of its hand group is held
---@field repress number work of a press right after its column released, falling to 0 at repress_window
---@field repress_window number seconds
---@field window number seconds
---@field group_power number power mean of the groups' work per second; idle groups count as 0
---@field power number power mean over windows
---@field curve number the LN level is scale * raw^curve
---@field combine number power sum of the short-note rating and the LN level
---@field long_release number work of a release after a hold of long_full or longer, less after shorter ones
---@field long_full number seconds
---@field scale number

--- Index of the last element of a sorted list at or before t, 0 when there is none.
---@param list number[]
---@param t number
---@return integer
local function last_before(list, t)
	local lo, hi = 0, #list
	while lo < hi do
		local mid = math.floor((lo + hi + 1) / 2)
		if list[mid] <= t then
			lo = mid
		else
			hi = mid - 1
		end
	end
	return lo
end

---@param x number
---@return number
local function clamp01(x)
	return math.min(math.max(x, 0), 1)
end

---Raw LN rating, 0 without holds of min_hold or longer.
---@param times number[] note starts, sorted, seconds
---@param cols integer[] columns from 1
---@param ends {[integer]: number} hold ends by note index, nil for taps
---@param groups integer[] hand group of each column, from 1
---@param p chart.scoring.rizucalc_ln.Params
---@return number
function rizucalc_ln.raw(times, cols, ends, groups, p)
	local n = #times
	---@type {[integer]: number[]}, {[integer]: number[]}
	local starts, hold_ends = {}, {}
	-- events: presses 1..n, then releases of holds in note order
	---@type number[], integer[], boolean[], number[]
	local ev_t, ev_c, release, work = {}, {}, {}, {}
	for i = 1, n do
		ev_t[i], ev_c[i], release[i], work[i] = times[i], cols[i], false, 0
	end
	for i = 1, n do
		local e = ends[i]
		if e and e - times[i] >= p.min_hold then
			local c = cols[i]
			starts[c] = starts[c] or {}
			hold_ends[c] = hold_ends[c] or {}
			table.insert(starts[c], times[i])
			table.insert(hold_ends[c], e)
			table.insert(ev_t, e)
			table.insert(ev_c, c)
			table.insert(release, true)
			table.insert(work, p.long_release * math.min((e - times[i]) / p.long_full, 1))
		end
	end
	if #ev_t == n then
		return 0
	end

	for k = 1, #ev_t do
		local t, c = ev_t[k], ev_c[k]
		for c2, start in pairs(starts) do
			if c2 ~= c and groups[c2] == groups[c] then
				local j = last_before(start, t - LN_MARGIN)
				if j > 0 and hold_ends[c2][j] > t + LN_MARGIN then
					work[k] = work[k] + p.held
					break
				end
			end
		end
		if not release[k] and hold_ends[c] then
			local j = last_before(hold_ends[c], t)
			if j > 0 then
				work[k] = work[k] + p.repress * clamp01(1 - (t - hold_ends[c][j]) / p.repress_window)
			end
		end
	end

	local n_groups = 0
	for _, g in ipairs(groups) do
		n_groups = math.max(n_groups, g)
	end
	local t0 = times[1]
	---@type {[integer]: {[integer]: number}}, {[integer]: integer}
	local sums, count = {}, {}
	local nw = 0
	for k = 1, #ev_t do
		local w = math.floor((ev_t[k] - t0) / p.window)
		nw = math.max(nw, w + 1)
		count[w] = (count[w] or 0) + 1
		local g = groups[ev_c[k]]
		sums[g] = sums[g] or {}
		sums[g][w] = (sums[g][w] or 0) + work[k]
	end
	local total, weight = 0, 0
	for w = 0, nw - 1 do
		local c = count[w]
		if c then
			local s = 0
			for g = 1, n_groups do
				s = s + ((sums[g] and sums[g][w] or 0) / p.window) ^ p.group_power
			end
			local strain = (s / n_groups) ^ (1 / p.group_power) ---@type number
			total = total + c * strain ^ p.power
			weight = weight + c
		end
	end
	return (total / weight) ^ (1 / p.power)
end

return rizucalc_ln
