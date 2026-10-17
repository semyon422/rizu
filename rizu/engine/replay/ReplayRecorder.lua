local VirtualInputEvent = require("rizu.input.VirtualInputEvent")
local class = require("class")

---@class rizu.ReplayRecorder
---@operator call: rizu.ReplayRecorder
local ReplayRecorder = class()

function ReplayRecorder:new()
	---@type rizu.ReplayFrame[]
	self.frames = {}
end

---@param time number
---@param event rizu.VirtualInputEvent
function ReplayRecorder:record(time, event)
	local pos = event.pos
	local snapshot = VirtualInputEvent(event.id, event.value, event.column, pos and {pos[1], pos[2]})
	table.insert(self.frames, {
		time = time,
		event = snapshot
	})
end

---@return rizu.ReplayFrame[]
function ReplayRecorder:getFrames()
	return self.frames
end

return ReplayRecorder
