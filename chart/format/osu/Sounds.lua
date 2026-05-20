local class = require("class")
local bit = require("bit")
local table_util = require("table_util")
local math_util = require("math_util")

---@class chart.osu.Sound
---@field name string
---@field fallback_name string?
---@field volume number
---@field is_keysound boolean?

---@class chart.osu.Sounds
---@operator call: chart.osu.Sounds
local Sounds = class()

local SoundType = {
	None = 0,
	Normal = 1,
	Whistle = 2,
	Finish = 4,
	Clap = 8,
}

local SampleSet = {
	None = 0,
	Normal = 1,
	Soft = 2,
	Drum = 3,
}

local SoundVolume = {
	Normal = 0.8,
	Whistle = 0.85,
	Finish = 1,
	Clap = 0.85,
}

local SoundOrder = {
	"Normal",
	"Finish",
	"Whistle",
	"Clap",
}

local function is_type(_type, v)
	return bit.band(_type, v) ~= 0
end

---@param id number
---@return string
function Sounds:getSampleSetName(id)
	return SampleSet[id] or "normal"
end

---@param soundType number
---@param sampleSet number
---@param addSampleSet number
---@param customSampleSet number
---@param is_taiko boolean?
---@return string
---@return string?
function Sounds:getSampleName(soundType, sampleSet, addSampleSet, customSampleSet, is_taiko)
	if soundType ~= SoundType.Normal then
		sampleSet = addSampleSet
	end

	---@type string
	local strSoundType = (table_util.keyof(SoundType, soundType) or "None"):lower()

	if sampleSet == SampleSet.None then
		sampleSet = SampleSet.Soft
	end
	---@type string
	local strSampleSet = (table_util.keyof(SampleSet, sampleSet) or "None"):lower()
	local customSample = math.max(customSampleSet, 0)
	local modePrefix = is_taiko and "taiko-" or ""

	local name = ("%s%s-hit%s"):format(
		modePrefix,
		strSampleSet,
		strSoundType
	)
	if customSample == 0 then
		return name
	end

	return name .. customSample, name
end

---@param soundType number
---@param addition chart.osu.Addition
---@param point chart.osu.ControlPoint
---@return chart.osu.Sound[]
function Sounds:decode(soundType, addition, point)
	local real_volume = 100
	if addition.volume > 0 then
		real_volume = addition.volume
	elseif point.volume > 0 then
		real_volume = point.volume
	end
	real_volume = math.max(real_volume, 8)

	---@type osu.Sound[]
	local real_sounds = {}

	if addition.sampleFile and addition.sampleFile ~= "" then
		real_sounds[1] = {
			name = addition.sampleFile,
			volume = real_volume,
			is_keysound = true,
		}
		return real_sounds
	end

	local sampleSetId = 0
	if addition.sampleSet ~= 0 then
		sampleSetId = addition.sampleSet
	else
		sampleSetId = point.sampleSet
	end

	local addSampleSet = sampleSetId
	if addition.addSampleSet ~= 0 then
		addSampleSet = addition.addSampleSet
	end

	local customSample = 0
	if addition.customSample ~= 0 then
		customSample = addition.customSample
	elseif point.customSamples ~= 0 then
		customSample = point.customSamples
	end

	for _, name in ipairs(SoundOrder) do
		local Type = SoundType[name]
		if is_type(Type, soundType) then
			local _name, fallback_name = self:getSampleName(Type, sampleSetId, addSampleSet, customSample)
			table.insert(real_sounds, {
				name = _name,
				fallback_name = fallback_name,
				volume = real_volume * SoundVolume[name],
			})
		end
	end

	if #real_sounds == 0 then
		local _name, fallback_name = self:getSampleName(SoundType.Normal, sampleSetId, addSampleSet, customSample)
		table.insert(real_sounds, {
			name = _name,
			fallback_name = fallback_name,
			volume = real_volume * SoundVolume.Normal,
		})
	end

	return real_sounds
end

---@param s string
---@return number
---@return number
---@return number
---@return number
function Sounds:encodeSoundName(s)
	local is_taiko = s:find("^taiko-") ~= nil
	if is_taiko then
		s = s:sub(7)
	end

	local strSampleSet, strSoundType, customSampleSet = s:match("^(%a+)-hit(%a+)(%d*)$")
	if not strSampleSet then
		return
	end
	customSampleSet = tonumber(customSampleSet) or 0

	strSampleSet = strSampleSet:sub(1, 1):upper() .. strSampleSet:sub(2)
	strSoundType = strSoundType:sub(1, 1):upper() .. strSoundType:sub(2)

	local sampleSet = SampleSet[strSampleSet]
	local soundType = SoundType[strSoundType]

	local volume_factor = SoundVolume[strSoundType]

	return sampleSet, soundType, customSampleSet, volume_factor
end

---@param sounds chart.osu.Sound[]
---@return number soundType
---@return chart.osu.Addition addition
function Sounds:encode(sounds)
	local addition = {
		addSampleSet = 0,
		customSample = 0,
		sampleFile = "",
		sampleSet = 0,
		volume = 0,
	}
	---@cast addition osu.Addition

	local ret_soundType = 0

	for _, s in ipairs(sounds) do
		addition.volume = s.volume
		if s.is_keysound then
			addition.sampleFile = s.name
			return SoundType.None, addition
		end
		local sampleSet, soundType, customSampleSet, volume_factor = self:encodeSoundName(s.name)
		addition.sampleSet = sampleSet
		addition.customSample = customSampleSet
		addition.volume = math_util.round(s.volume / volume_factor)
		ret_soundType = bit.bor(ret_soundType, soundType)
	end

	return ret_soundType, addition
end

return Sounds
