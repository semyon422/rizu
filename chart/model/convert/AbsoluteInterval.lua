local class = require("class")
local table_util = require("table_util")
local Vertex = require("chart.model.to.Interval")
local IntervalPoint = require("chart.model.tp.IntervalPoint")
local IntervalLayer = require("chart.model.layers.IntervalLayer")
local TempoConnector = require("chart.model.convert.TempoConnector")
local Restorer = require("chart.model.visual.Restorer")
local Fraction = require("chart.core.Fraction")

---@class chart.AbsoluteInterval
---@operator call: chart.AbsoluteInterval
local AbsoluteInterval = class()

AbsoluteInterval.min_beat_duration = 0.080  -- 750 bpm, 1/16 = 5ms

AbsoluteInterval.min_absolute_time = -24 * 60 * 60  -- -1 day
AbsoluteInterval.max_absolute_time = 24 * 60 * 60  -- 1 day

local default_denoms = {1, 2, 3, 4, 5, 6, 7, 8, 9, 12, 16}
local default_merge_time = 0.002

---@param denoms number[]
---@param merge_time number
function AbsoluteInterval:new(denoms, merge_time)
	denoms = denoms or default_denoms
	merge_time = merge_time or default_merge_time
	self.denoms = denoms
	self.tempoConnector = TempoConnector(denoms[#denoms], merge_time)
end

---@param n number
---@return chart.Fraction
function AbsoluteInterval:bestFraction(n)
	local _delta = math.huge
	local _denom = 1
	for _, denom in ipairs(self.denoms) do
		local delta = math.abs(Fraction(n, denom, "round"):tonumber() - n)
		if delta < _delta then
			_denom = denom
			_delta = delta
		end
	end
	return Fraction(n, _denom, "round")
end

---@param dur number
---@return number
function AbsoluteInterval:clampTempo(dur)
	local mbd = self.min_beat_duration
	if dur < 0.001 then
		return mbd
	end
	while dur < mbd do
		dur = dur * 2
	end
	return dur
end

---@param points chart.AbsolutePoint[]
---@return chart.Tempo[]
---@return {[chart.Tempo]: number}
function AbsoluteInterval:loadTempos(points)
	---@type {[chart.Tempo]: number}
	local tempo_offsets = {}

	---@type chart.Tempo[]
	local tempos = {}

	for _, point in ipairs(points) do
		local _tempo = point._tempo
		if _tempo then
			table.insert(tempos, _tempo)
			tempo_offsets[_tempo] = point.absoluteTime
		end
	end

	return tempos, tempo_offsets
end

---@param points chart.AbsolutePoint[]
---@return {[chart.Fraction]: chart.Vertex}
---@return {[chart.Tempo]: number}
---@return {[chart.Tempo]: number}
---@return {[chart.Tempo]: chart.Fraction}
function AbsoluteInterval:computeTempos(points)
	local tempos, tempo_offsets = self:loadTempos(points)

	---@type {[ncdk.Fraction]: chart.Vertex}
	local intervals = {}
	---@type {[chart.Tempo]: number}
	local tempo_beat_offsets = {}
	---@type {[chart.Tempo]: ncdk.Fraction}
	local tempo_beats = {}

	if #tempos == 0 then
		return intervals, tempo_beat_offsets, tempo_offsets, tempo_beats
	end

	local total_beats = 0
	tempo_beat_offsets[tempos[1]] = total_beats
	intervals[Fraction(0)] = Vertex(tempo_offsets[tempos[1]])

	---@type {[number]: chart.Vertex}
	local offset_intervals = {}

	for i = 2, #tempos  do
		local prev_tempo, tempo = tempos[i - 1], tempos[i]
		local offset = tempo_offsets[prev_tempo]
		local beat_duration = self:clampTempo(prev_tempo:getBeatDuration())

		local beats, aux_interval, int_beats = self.tempoConnector:connect(
			offset,
			beat_duration,
			tempo_offsets[tempo]
		)

		tempo_beats[prev_tempo] = beats

		if aux_interval and beats[1] ~= 0 then
			local aux_offset = beats:tonumber() * beat_duration + offset
			local vertex = Vertex(aux_offset)
			assert(not offset_intervals[aux_offset], aux_offset)
			offset_intervals[aux_offset] = vertex
			intervals[beats + total_beats] = vertex
		end

		total_beats = total_beats + int_beats
		local _offset = tempo_offsets[tempo]
		local vertex = Vertex(_offset)
		assert(not offset_intervals[_offset], _offset)
		offset_intervals[_offset] = vertex
		intervals[Fraction(total_beats)] = vertex

		tempo_beat_offsets[tempo] = total_beats
	end

	return intervals, tempo_beat_offsets, tempo_offsets, tempo_beats
end

---@param layer chart.AbsoluteLayer
---@param fraction_mode any
function AbsoluteInterval:convert(layer, fraction_mode)
	if not fraction_mode then
		fraction_mode = false
	end

	---@type chart.AbsolutePoint[]
	local points = layer:getPointList()

	local intervals, tempo_beat_offsets, tempo_offsets, tempo_beats = self:computeTempos(points)

	if not next(intervals) then
		---@cast layer -chart.AbsoluteLayer, +chart.IntervalLayer
		setmetatable(layer, IntervalLayer)
		table_util.clear(layer)
		layer:new()
		return
	end

	---@type {[string]: chart.IntervalPoint}
	local points_map = {}

	---@type ncdk.Fraction
	local prev_time

	local prev_absoluteTime = 0

	local min_time = math.huge
	local max_time = -math.huge

	-- fix for 1e300 time
	local min_abs_time = self.min_absolute_time
	local max_abs_time = self.max_absolute_time
	for i, p in ipairs(points) do
		local t = p.absoluteTime
		if t >= min_abs_time and t <= max_abs_time then
			min_time = math.min(min_time, t)
			max_time = math.max(max_time, t)
		end
	end

	for i, p in ipairs(points) do
		local absoluteTime = math.min(math.max(p.absoluteTime, min_time), max_time)

		local tempo = assert(p.tempo)

		local tempo_offset = tempo_offsets[tempo]
		local beat_duration = self:clampTempo(tempo:getBeatDuration())
		local rel_time_n = (absoluteTime - tempo_offset) / beat_duration
		local rel_time = self:bestFraction(rel_time_n)
		if tempo_beats[tempo] and rel_time > tempo_beats[tempo] then
			rel_time = Fraction(rel_time:ceil())
		end

		local time = rel_time + tempo_beat_offsets[tempo]

		if i == 1 and not p._tempo then
			local time_ceil_n = time:floor()
			local beats = time_ceil_n - tempo_beat_offsets[tempo]
			intervals[Fraction(time_ceil_n)] = Vertex(tempo_offset + beat_duration * beats)
		elseif i == #points and not p._tempo then
			local time_ceil_n = time:ceil()
			local beats = time_ceil_n - tempo_beat_offsets[tempo]
			intervals[Fraction(time_ceil_n)] = Vertex(tempo_offset + beat_duration * beats)
		end

		---@cast p -chart.AbsolutePoint, +chart.IntervalPoint
		setmetatable(p, IntervalPoint)
		table_util.clear(p)

		if prev_time then
			assert(time >= prev_time, "time is not monotonic")
		end
		prev_time = time

		p:new(time)
		points_map[tostring(p)] = p  -- more than one point can use same key, fix this below
	end

	for _, visual in pairs(layer.visuals) do
		for _, visualPoint in ipairs(visual.points) do
			visualPoint.point = points_map[tostring(visualPoint.point)]
		end
	end

	local visuals = layer.visuals

	---@cast layer -chart.AbsoluteLayer, +chart.IntervalLayer
	setmetatable(layer, IntervalLayer)
	table_util.clear(layer)

	layer:new()
	layer.points = points_map
	layer.visuals = visuals

	for time, vertex in pairs(intervals) do
		local p = layer:getPoint(time)
		p._vertex = vertex
	end

	layer.intervalCompute:compute(layer:getPointList())

	for name, visual in pairs(layer.visuals) do
		---@type number[]
		local vts = {}
		for i, vp in ipairs(visual.points) do
			vts[i] = vp.visualTime
		end
		Restorer:restore(visual.points)
		visual:compute()
		local sum = 0
		local sum2 = 0
		for i, vp in ipairs(visual.points) do
			local delta = vts[i] - vp.visualTime
			sum = sum + delta
			sum2 = sum2 + delta ^ 2
		end
		-- print(name, math.sqrt(math.abs(sum2 / #vts - (sum / #vts) ^ 2)))
	end

	layer:validate()
end

return AbsoluteInterval
