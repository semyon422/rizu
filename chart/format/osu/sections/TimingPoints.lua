local string_util = require("string_util")
local bit = require("bit")
local Section = require("chart.format.osu.sections.Section")

---@class chart.osu.ControlPoint
---@field offset number
---@field beatLength number
---@field timeSignature number
---@field sampleSet number
---@field customSamples number
---@field volume number
---@field timingChange boolean
---@field kiai boolean
---@field omitFirstBarLine boolean

---@class chart.osu.TimingPoints: chart.osu.Section
---@operator call: chart.osu.TimingPoints
---@field [integer] chart.osu.ControlPoint
local TimingPoints = Section + {}

TimingPoints.sampleVolume = 100
TimingPoints.defaultSampleSet = 0

local EffectFlags = {
	None = 0,
	Kiai = 1,
	OmitFirstBarLine = 8,
}

---@param sampleVolume number
---@param defaultSampleSet number
function TimingPoints:new(sampleVolume, defaultSampleSet)
	self.sampleVolume = sampleVolume
	self.defaultSampleSet = defaultSampleSet
end

function TimingPoints:sort()
	table.sort(self, function(a, b)
		if a.offset ~= b.offset then
			return a.offset < b.offset
		end
		return a.beatLength > b.beatLength
	end)
end

---@param line string
function TimingPoints:decodeLine(line)
	---@type string[]
	local split = string_util.split(line, ",")
	local size = #split

	if size < 2 then
		return
	end

	---@type number[]
	local splitn = {}
	for i, v in ipairs(split) do
		splitn[i] = assert(tonumber(v))
	end

	local point = {}
	---@cast point osu.ControlPoint

	point.offset = splitn[1]
	point.beatLength = splitn[2]

	if size == 2 then
		point.timeSignature = 4
		point.sampleSet = self.defaultSampleSet
		point.customSamples = 0
		point.volume = 100
		point.timingChange = true
		point.kiai = false
		point.omitFirstBarLine = false
		table.insert(self, point)
		return
	end

	point.timeSignature = math.floor(splitn[3] == 0 and 4 or splitn[3] or 4)
	point.sampleSet = splitn[4] or 0
	point.customSamples = splitn[5] or 0
	point.volume = splitn[6] or self.sampleVolume
	point.timingChange = splitn[7] == 1
	if not splitn[7] then
		point.timingChange = true  -- can't use `or` here
	end

	local effectFlags = splitn[8] or 0
	point.kiai = bit.band(effectFlags, EffectFlags.Kiai) ~= 0
	point.omitFirstBarLine = bit.band(effectFlags, EffectFlags.OmitFirstBarLine) ~= 0

	table.insert(self, point)
end

---@return string[]
function TimingPoints:encode()
	local out = {}

	for _, p in ipairs(self) do
		local effectFlags = 0
		effectFlags = bit.bor(effectFlags, p.kiai and EffectFlags.Kiai or 0)
		effectFlags = bit.bor(effectFlags, p.omitFirstBarLine and EffectFlags.OmitFirstBarLine or 0)
		table.insert(out, ("%.16g,%.16g,%s,%s,%s,%s,%s,%s"):format(
			p.offset or 0,
			p.beatLength or 1000,
			p.timeSignature or 4,
			p.sampleSet or 0,
			p.customSamples or 0,
			p.volume or 0,
			p.timingChange and 1 or 0,
			effectFlags
		))
	end

	-- osu adds \r\n at the end of each timing point
	-- and one new line before each section
	-- that is why there is additional empty line
	table.insert(out, "")

	return out
end

return TimingPoints
