local class = require("class")
local valid = require("valid")
local types = require("sea.shared.types")

---@alias rizu.VirtualInputEventId integer
---@alias rizu.VirtualInputEventValue false|true|"left"|"right"

---@class rizu.VirtualInputEvent
---@operator call: rizu.VirtualInputEvent
local VirtualInputEvent = class()

---@param id rizu.VirtualInputEventId
---@param value rizu.VirtualInputEventValue?
---@param column integer
---@param pos [number, number]?
function VirtualInputEvent:new(id, value, column, pos)
	assert(id, "VirtualInputEvent requires an id")
	self.id = id
	self.value = value
	self.column = column
	self.pos = pos
end

VirtualInputEvent.struct = {
	id = types.integer,
	value = valid.optional(valid.one_of({false, true, "left", "right"})),
	column = types.integer,
	pos = valid.optional(valid.tuple({types.number, types.number})),
}

local validate = valid.struct(VirtualInputEvent.struct)

---@return true?
---@return string|valid.Errors?
function VirtualInputEvent:validate()
	return validate(self)
end

return VirtualInputEvent
