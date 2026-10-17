local class = require("class")
local valid = require("valid")
local types = require("sea.shared.types")

---@alias sea.TimingObjectKey "ShortNote"|"LongNoteStart"|"LongNoteEnd"
---@alias sea.TimingObjectValues {hit: {[1]: number, [2]: number}, miss: {[1]: number, [2]: number}}
---@alias sea.TimingResult "exactly"|"early"|"late"|"too early"|"too late"

local validate_timing_object_values = valid.struct({
	hit = valid.struct({[1] = types.number, [2] = types.number}),
	miss = valid.struct({[1] = types.number, [2] = types.number}),
})

local eps = 1e-9

---@param a sea.TimingObjectValues
---@param b sea.TimingObjectValues
local function equals_values(a, b)
	return
		math.abs(a.hit[1] - b.hit[1]) < eps and
		math.abs(a.hit[2] - b.hit[2]) < eps and
		math.abs(a.miss[1] - b.miss[1]) < eps and
		math.abs(a.miss[2] - b.miss[2]) < eps
end

-- TODO: user NoteType+weight as key

---@class sea.TimingValues
---@operator call: sea.TimingValues
---@field [sea.TimingObjectKey] sea.TimingObjectValues
local TimingValues = class()

function TimingValues:new()
	self:setSimple(0, 0)
end

---@param h number
---@param m number?
---@return sea.TimingValues
function TimingValues:setSimple(h, m)
	m = m or h
	self.ShortNote = {hit = {-h, h}, miss = {-m, m}}
	self.LongNoteStart = {hit = {-h, h}, miss = {-m, m}}
	self.LongNoteEnd = {hit = {-h, h}, miss = {-m, m}}
	return self
end

---@param tvs sea.TimingValues
---@return boolean
function TimingValues:equals(tvs)
	return
		equals_values(self.ShortNote, tvs.ShortNote) and
		equals_values(self.LongNoteStart, tvs.LongNoteStart) and
		equals_values(self.LongNoteEnd, tvs.LongNoteEnd)
end

---@param values sea.TimingValues
function TimingValues:copyFrom(values)
	self.ShortNote = values.ShortNote
	self.LongNoteStart = values.LongNoteStart
	self.LongNoteEnd = values.LongNoteEnd
	return self
end

local validate_timing_values = valid.struct({
	ShortNote = validate_timing_object_values,
	LongNoteStart = validate_timing_object_values,
	LongNoteEnd = validate_timing_object_values,
})

---@return true?
---@return string|valid.Errors?
function TimingValues:validate()
	return validate_timing_values(self)
end

---@param key sea.TimingObjectKey
---@param dt number
---@return sea.TimingResult
function TimingValues:hit(key, dt)
	---@type sea.TimingObjectValues
	local values = self[key]
	local hit, miss = values.hit, values.miss
	if dt >= hit[1] and dt <= hit[2] then
		return "exactly"
	elseif dt >= miss[1] and dt < hit[1] then
		return "early"
	elseif dt > hit[2] and dt <= miss[2] then
		return "late"
	elseif dt < miss[1] then
		return "too early"
	elseif dt > miss[2] then
		return "too late"
	end
	error("invalid TimingValues or dt")
end

---@param key sea.TimingObjectKey
---@return number
function TimingValues:getMaxTime(key)
	---@type sea.TimingObjectValues
	local values = self[key]
	return values.miss[2]
end

---@param key sea.TimingObjectKey
---@return number
function TimingValues:getMinTime(key)
	---@type sea.TimingObjectValues
	local values = self[key]
	return values.miss[1]
end

return TimingValues
