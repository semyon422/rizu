local class = require("class")
local TimingValues = require("sea.chart.TimingValues")

---@class rizu.LogicNoteChange
---@field index integer
---@field type "tap"|"hold"
---@field time number
---@field delta_time number
---@field press_delta_time number? -- head/re-press offset for a hold press
---@field old_state string
---@field new_state string

---@class rizu.LogicInfo
---@operator call: rizu.LogicInfo
---@field time number
---@field rate number
---@field timing_values sea.TimingValues
---@field note_changes rizu.LogicNoteChange[]
---@field on_note_change fun(change: rizu.LogicNoteChange)?
local LogicInfo = class()

function LogicInfo:new()
	self.time = 0
	self.rate = 1
	self.timing_values = TimingValues()
	self.note_changes = {}
end

---@return number
function LogicInfo:getTime()
	return self.time
end

---@param time number
---@return number
function LogicInfo:sub(time)
	return (self:getTime() - time) / self.rate
end

---@param key sea.TimingObjectKey
---@return number
function LogicInfo:getNoteMinTime(key)
	return self.timing_values:getMinTime(key) * self.rate
end

---@param key sea.TimingObjectKey
---@return number
function LogicInfo:getNoteMaxTime(key)
	return self.timing_values:getMaxTime(key) * self.rate
end

---@param change rizu.LogicNoteChange
function LogicInfo:addNoteChange(change)
	table.insert(self.note_changes, change)
	if self.on_note_change then
		self.on_note_change(change)
	end
end

return LogicInfo
