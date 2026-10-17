local class = require("class")

---@class rizu.InputPauser
---@operator call: rizu.InputPauser
local InputPauser = class()

function InputPauser:new()
	---@type {[rizu.VirtualInputEventId]: any}
	self.event_values = {}

	---@type {[rizu.InputNote]: any}
	self.paused_notes = {}
end

---@param id rizu.VirtualInputEventId
---@param value any?
function InputPauser:receive(id, value)
	local event_values = self.event_values

	if value ~= nil then
		event_values[id] = value or nil
	end
end

---@param catched_notes {[rizu.InputNote]: rizu.VirtualInputEventId}
function InputPauser:pause(catched_notes)
	self.paused = true

	local paused_notes = self.paused_notes
	local event_values = self.event_values

	for note, id in pairs(catched_notes) do
		paused_notes[note] = event_values[id]
	end
end

---@param catched_notes {[rizu.InputNote]: rizu.VirtualInputEventId}
function InputPauser:resume(catched_notes)
	self.paused = false

	local paused_notes = self.paused_notes
	local event_values = self.event_values

	---@type {[rizu.InputNote]: true}
	local handled_notes = {}

	for note, value in pairs(paused_notes) do
		paused_notes[note] = nil
		handled_notes[note] = true

		local new_value = event_values[catched_notes[note]] or false
		if value ~= new_value then
			note:input(new_value)
		end
	end

	for note, id in pairs(catched_notes) do
		if not handled_notes[note] then
			local new_value = event_values[id]
			note:input(new_value)
		end
	end
end

return InputPauser
