local class = require("class")
local Sounds = require("chart.format.osu.Sounds")
local PrimaryTempo = require("chart.format.osu.PrimaryTempo")
local Barlines = require("chart.format.osu.Barlines")

---@class chart.osu.ProtoTempo
---@operator call: chart.osu.ProtoTempo
---@field offset number
---@field tempo number
---@field signature number
local ProtoTempo = class()

---@class chart.osu.ProtoVelocity
---@operator call: chart.osu.ProtoVelocity
---@field offset number
---@field velocity number
local ProtoVelocity = class()

---@class chart.osu.ProtoNote
---@operator call: chart.osu.ProtoNote
---@field time number
---@field endTime number?
---@field column number
---@field is_double boolean
---@field sounds chart.osu.Sound[]
local ProtoNote = class()

---@class chart.osu.FilteredPoint
---@field offset number
---@field beatLength number?
---@field velocity number?
---@field signature number?
---@field omitFirstBarLine boolean?

---@class chart.osu.Osu
---@operator call: chart.osu.Osu
---@field protoTempos chart.osu.ProtoTempo[]
---@field protoVelocities chart.osu.ProtoVelocity[]
---@field protoNotes chart.osu.ProtoNote[]
---@field keymode number
local Osu = class()

---@param rawOsu chart.osu.RawOsu
function Osu:new(rawOsu)
	self.rawOsu = rawOsu
	self.protoTempos = {}
	self.protoVelocities = {}
	self.protoNotes = {}
end

function Osu:decode()
	self.keymode = math.floor(self.rawOsu.Difficulty.CircleSize)
	self:decodeHitObjects()
	self:decodeTimingPoints()
end

---@return string
function Osu:encode()
	return self.rawOsu:encode()
end

function Osu:decodeTimingPoints()
	local points = self.rawOsu.TimingPoints
	for _, p in ipairs(points) do
		p.timingChange = p.beatLength >= 0  -- real timingChange
	end

	---@type {[number]: osu.FilteredPoint}
	local filtered_points = {}

	---@type {[number]: boolean}, {[number]: boolean}
	local red_points, green_points = {}, {}

	for i = #points, 1, -1 do
		local p = points[i]
		local offset = p.offset
		if p.timingChange and not red_points[offset] then
			red_points[offset] = true
			filtered_points[offset] = filtered_points[offset] or {offset = offset}
			filtered_points[offset].beatLength = p.beatLength
			filtered_points[offset].signature = math.max(1, math.abs(p.timeSignature))
			filtered_points[offset].omitFirstBarLine = p.omitFirstBarLine
		elseif not p.timingChange and not green_points[offset] then
			green_points[offset] = true
			filtered_points[offset] = filtered_points[offset] or {offset = offset}
			filtered_points[offset].velocity = math.min(math.max(0.1, math.abs(-100 / p.beatLength)), 10)
		end
	end

	---@type osu.FilteredPoint[]
	local tempo_points = {}
	for _, p in pairs(filtered_points) do
		if p.beatLength then
			table.insert(tempo_points, p)
		end
	end
	table.sort(tempo_points, function(a, b)
		return a.offset < b.offset
	end)
	self.primary_tempo, self.min_tempo, self.max_tempo = PrimaryTempo:compute(tempo_points, self.maxTime)
	self.barlines = Barlines:generate(tempo_points, self.maxTime)

	for offset, fp in pairs(filtered_points) do
		local velocity = fp.velocity
		if fp.beatLength then
			table.insert(self.protoTempos, ProtoTempo({
				offset = offset,
				tempo = 60000 / fp.beatLength,
				signature = fp.signature,
			}))
			if not velocity then
				velocity = 1
			end
		end
		if velocity then
			table.insert(self.protoVelocities, ProtoVelocity({
				offset = offset,
				velocity = velocity,
			}))
		end
	end

	table.sort(self.protoTempos, function(a, b)
		return a.offset < b.offset
	end)
	table.sort(self.protoVelocities, function(a, b)
		return a.offset < b.offset
	end)
end

local function get_taiko_type(soundType)
	local column, is_double = 0, false
	if bit.band(soundType, 10) ~= 0 then  -- 2 | 8
		column = 2  -- kat
	else
		column = 1  -- don
	end
	is_double = bit.band(soundType, 4) ~= 0
	return column, is_double
end

function Osu:decodeHitObjects()
	self.maxTime = 0
	self.minTime = math.huge

	local mode = tonumber(self.rawOsu.General.Mode)
	local keymode = self.keymode

	local points = self.rawOsu.TimingPoints
	if #points == 0 then
		self.minTime = 0
		return
	end

	local p_i = 1
	local p = points[p_i]
	for _, obj in ipairs(self.rawOsu.HitObjects) do
		local next_p = points[p_i + 1]
		if next_p and obj.time >= next_p.offset then
			p = next_p
			p_i = p_i + 1
		end

		local column, is_double = 0, false
		if mode == 1 then
			column, is_double = get_taiko_type(obj.soundType)
		elseif mode == 3 then
			column = math.max(1, math.min(keymode, math.floor(obj.x / 512 * keymode + 1)))
		end

		local sounds = Sounds:decode(obj.soundType, obj.addition, p)
		table.insert(self.protoNotes, {
			time = obj.time,
			endTime = obj.endTime,
			column = column,
			is_double = is_double,
			sounds = sounds,
		})

		local time = obj.time
		local endTime = obj.endTime
		if time and time == time then  -- nan check
			self.maxTime = math.max(self.maxTime, time)
			self.minTime = math.min(self.minTime, time)
		end
		if endTime and endTime == endTime then  -- nan check
			self.maxTime = math.max(self.maxTime, endTime)
			self.minTime = math.min(self.minTime, endTime)
		end
	end
	if self.minTime == math.huge then
		self.minTime = 0
	end
end

return Osu
