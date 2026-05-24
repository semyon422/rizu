local Section = require("chart.format.osu.sections.Section")
local Addition = require("chart.format.osu.sections.Addition")
local bit = require("bit")
local string_util = require("string_util")

---@class chart.osu.HitObject
---@field x number
---@field y number
---@field time number
---@field endTime number?
---@field type number
---@field soundType number
---@field repeatCount number?
---@field length number?
---@field curveType string?
---@field points chart.osu.Vector2[]?
---@field sounds number[]?
---@field ss number[]?
---@field ssa number[]?
---@field addition chart.osu.Addition

---@alias chart.osu.Vector2 number[]

---@class chart.osu.HitObjects: chart.osu.Section
---@operator call: chart.osu.HitObjects
---@field [integer] chart.osu.HitObject
local HitObjects = Section + {}

local HitObjectType = {
	Normal = 1,
	Slider = 2,
	NewCombo = 4,
	NormalNewCombo = 5,
	SliderNewCombo = 6,
	Spinner = 8,
	ColourHax = 112,
	Hold = 128,
	ManiaLong = 128,
}
HitObjects.HitObjectType = HitObjectType

local function is_type(_type, v)
	return bit.band(_type, v) ~= 0
end

---@param object chart.osu.HitObject
---@param split string[]
---@param soundType number
local function decode_osu_slider(object, split, soundType)
	local curveType = "C"
	local repeatCount = 0
	local length = 0

	---@type osu.Vector2[]
	local points = {}

	---@type number[]
	local sounds = nil

	---@type string[]
	local pointsplit = string_util.split(split[6], "|")
	for i = 1, #pointsplit do
		local point = pointsplit[i]
		if #point == 1 then
			curveType = point
			goto continue
		end

		---@type string[]
		local temp = string_util.split(point, ":")

		---@type osu.Vector2
		local v = {tonumber(temp[1]), tonumber(temp[2])}
		table.insert(points, v)

		::continue::
	end

	object.curveType = curveType

	repeatCount = tonumber(split[7])
	assert(repeatCount <= 9000, "too many repeats")
	object.repeatCount = repeatCount

	if #split > 7 then
		length = tonumber(split[8])
	end
	if #split > 8 and #split[9] > 0 then
		---@type string[]
		local adds = string_util.split(split[9], "|")
		if #adds > 0 then
			sounds = {}
			local addslength = math.min(#adds, repeatCount + 1)
			for i = 1, addslength do
				table.insert(sounds, tonumber(adds[i]))
			end
			for i = addslength + 1, repeatCount + 1 do
				table.insert(sounds, soundType)
			end
		end
	end

	---@type number[]
	local ss = {}
	---@type number[]
	local ssa = {}

	if #split > 9 and #split[10] > 0 then
		---@type string[]
		local sets = string_util.split(split[10], "|")
		if #sets > 0 then
			for _, t in ipairs(sets) do
				---@type string[]
				local split2 = string_util.split(t, ":")
				table.insert(ss, tonumber(split2[1]))
				table.insert(ssa, tonumber(split2[2]))
			end
		end
	end

	if sounds then
		if #ss > repeatCount + 1 then
			for i = repeatCount + 1, repeatCount + 1 + #ss - repeatCount - 1 do
				ss[i + 1] = nil
			end
		else
			for z = #ss, repeatCount do
				table.insert(ss, 0)
			end
		end
		if #ssa > repeatCount + 1 then
			for i = repeatCount + 1, repeatCount + 1 + #ss - repeatCount - 1 do
				ssa[i + 1] = nil
			end
		else
			for z = #ssa, repeatCount do
				table.insert(ssa, 0)
			end
		end
	end

	if #split > 10 then
		object.addition = Addition(split[11])
	end
	object.addition = object.addition or Addition()

	object.points = points
	object.sounds = sounds
	object.length = length
	object.ss = ss
	object.ssa = ssa
end

---@param line string
function HitObjects:decodeLine(line)
	---@type string[]
	local split = string_util.split(line, ",")

	local object = {
		sampleSet = 0,
		addSampleSet = 0,
		customSample = 0,
		volume = 0,
	}
	---@cast object osu.HitObject

	object.x = math.min(math.max(tonumber(split[1]) or 0, 0), 512)
	object.y = math.min(math.max(tonumber(split[2]) or 0, 0), 512)
	object.time = tonumber(split[3]) or 0

	local _type = bit.band(tonumber(split[4]) or 0, bit.bnot(HitObjectType.ColourHax))
	object.type = _type
	object.soundType = tonumber(split[5]) or 0

	if is_type(HitObjectType.Normal, _type) then
		object.addition = Addition(split[6])
	elseif is_type(HitObjectType.Slider, _type) then
		local length = tonumber(split[8])
		object.endTime = length and object.time + length or object.time
		decode_osu_slider(object, split, object.soundType)
	elseif is_type(HitObjectType.Spinner, _type) then
		object.endTime = tonumber(split[6])
		object.addition = Addition(split[7])
	elseif is_type(HitObjectType.Hold, _type) then
		local a, b = split[6]:match("^(.-):(.+)$")
		if a then
			object.endTime = tonumber(a)
			object.addition = Addition(b)
		else
			object.endTime = tonumber(split[6])
			object.addition = Addition()
		end
	end
	object.addition = object.addition or Addition()

	table.insert(self, object)
end

function HitObjects:sort()
	table.sort(self, function(a, b)
		if a.time ~= b.time then
			return a.time < b.time
		end
		return a.x < b.x
	end)
end

---@return string[]
function HitObjects:encode()
	local out = {}

	for _, object in ipairs(self) do
		local extra = ""

		if is_type(HitObjectType.Slider, object.type) then
			if object.length == 0 then
				goto continue
			end
			extra = extra .. object.curveType .. "|"
			for _, p in ipairs(object.points) do
				extra = extra .. p[1] .. ":" .. p[2] .. "|"
			end
			extra = extra:gsub("|$", "")
			extra = extra .. "," .. object.repeatCount
			extra = extra .. "," .. object.length
			if object.sounds then
				extra = extra .. ","
				for _, sound in ipairs(object.sounds) do
					extra = extra .. sound .. "|"
				end
				extra = extra:gsub("|$", "")
				extra = extra .. ","
				for i = 1, #object.ss do
					extra = extra .. object.ss[i] .. ":" .. object.ssa[i] .. "|"
				end
				extra = extra:gsub("|$", "")
				extra = extra .. "," .. object.addition:encode()
			end
		elseif is_type(HitObjectType.Spinner, object.type) then
			extra = object.endTime .. "," .. object.addition:encode()
		elseif is_type(HitObjectType.Normal, object.type) then
			extra = object.addition:encode()
		elseif is_type(HitObjectType.Hold, object.type) then
			extra = object.endTime .. ":" .. object.addition:encode()
		end

		table.insert(out, ("%s,%s,%s,%s,%s,%s"):format(
			object.x,
			object.y,
			object.time,
			object.type,
			object.soundType,
			extra
		))
		::continue::
	end

	return out
end

return HitObjects
