--[[ beat
1-------------------2-------------------3-------------------4-------------------5
1-------------------|------2------------|-------------3-----|-------------------4
]]

-- 1/4 based
local snaps4 = {
	{"j", 1},
	{"j", 4 / 3},
	{"a", 2},
	{"a", 8 / 3},
	{"s", 3},
	-- {"s", 4},
}

-- 1/3 based
local snaps3 = {
	{"j", 3 / 4},
	{"j", 1},
	{"a", 6 / 4},
	{"a", 2},
	{"s", 9 / 4},
	{"s", 3},
}

local snaps = {}
do
	local snaps_map = {}
	for _, mp in ipairs({snaps4, snaps3}) do
		for _, peak in ipairs(mp) do
			snaps_map[peak[2]] = peak
		end
	end

	for _, peak in pairs(snaps_map) do
		table.insert(snaps, peak)
	end
	table.sort(snaps, function(a, b) return a[2] < b[2] end)
end

--------------------------------------------------------------------------------

local function get_line_intervals(time_list)
	local map = {}
	for i = 1, #time_list - 1 do
		local interval = time_list[i + 1] - time_list[i]
		map[interval] = (map[interval] or 0) + 1
	end
	return map
end

--------------------------------------------------------------------------------

local function combine_stats(stats)
	table.sort(stats, function(a, b) return a[1] < b[1] end)

	local _stats = {}
	local _stat
	for i = 1, #stats do
		local stat = stats[i]
		if not _stat then
			_stat = {stat[1], stat[2]}
		elseif math.abs(stat[1] - _stat[1]) <= 0.005 then
			_stat[1] = (_stat[1] * _stat[2] + stat[1] * stat[2]) / (_stat[2] + stat[2])
			_stat[2] = _stat[2] + stat[2]
		else
			table.insert(_stats, _stat)
			_stat = {stat[1], stat[2]}
		end
	end
	table.insert(_stats, _stat)

	return _stats
end

local function get_stats(map)
	local total = 0
	local stats = {}
	for interval, count in pairs(map) do
		table.insert(stats, {interval, count})
		total = total + count
	end
	stats = combine_stats(stats)
	table.sort(stats, function(a, b) return a[2] > b[2] end)

	for _, s in ipairs(stats) do
		s[2] = s[2] / total
	end

	return stats
end

---@param chart chart.Chart
---@return table
---@return table
local function load_layer(chart)
	local time_list = {}
	local time_map = {}
	local int_count_map = {}

	for column, notes in pairs(chart.notes:getColumnNotes()) do
		for i = 1, #notes - 1 do
			local time = notes[i]:getTime()
			local next_time = notes[i + 1]:getTime()

			time_map[time] = true
			time_map[next_time] = true

			local interval = next_time - time
			int_count_map[interval] = (int_count_map[interval] or 0) + 1
		end
	end

	for time in pairs(time_map) do
		table.insert(time_list, time)
	end
	table.sort(time_list)

	return time_list, int_count_map
end

local pattern_analyzer = {}

local pattern_names = {
	j = "jack",
	a = "alternate",
	s = "stream"
}

---@param chart chart.Chart
---@return table
---@return table
function pattern_analyzer.analyze(chart)
	local time_list, int_count_map = load_layer(chart)

	local all_stats = get_stats(int_count_map)
	local line_stats = get_stats(get_line_intervals(time_list))

	if not line_stats[1] then
		return {}, {}
	end

	local patterns = {}

	local baseInterval = line_stats[1][1]

	for i = 1, 10 do
		local stat = all_stats[i]
		if not stat then
			break
		end
		local ratio = stat[1] / baseInterval
		local _match

		for _, match in ipairs(snaps) do
			if math.abs(ratio - match[2]) <= 0.1 then
				_match = match
			end
		end

		if _match then
			local bpm = 60 / 4 / (_match[2] * baseInterval)
			if _match[1] == "a" then
				bpm = bpm * 2
			elseif _match[1] == "s" then
				bpm = bpm * 3
			end

			table.insert(patterns, {
				weight = stat[2],
				tempo = bpm,
				name = _match[1]
			})
		end
	end

	return patterns, line_stats
end

---@param patterns table
---@return string
function pattern_analyzer.format(patterns, line_stats)
	local out = {}

	for i, pattern in ipairs(patterns) do
		out[i] = ("%3d%% %0.f %s"):format(
			pattern.weight * 100,
			pattern.tempo,
			pattern_names[pattern.name]
		)
	end

	for i = 1, 3 do
		local stat = line_stats[i]
		if not stat then
			break
		end
		table.insert(out, ("%s %s %s"):format(i, ("%0.3f"):format(stat[1]), ("%3d%%"):format(stat[2] * 100)))
	end

	return table.concat(out, "\n")
end

return pattern_analyzer
