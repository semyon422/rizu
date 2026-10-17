local class = require("class")
local VirtualInputEvent = require("rizu.input.VirtualInputEvent")

---@class rizu.BottomNotesHandler
---@operator call: rizu.BottomNotesHandler
local BottomNotesHandler = class()

---@param active_notes rizu.ActiveInputNotes
function BottomNotesHandler:new(active_notes)
	self.active_notes = active_notes

	---@type {[rizu.VirtualInputEventId]: any}
	self.event_columns = {}
	---@type {[rizu.VirtualInputEventId]: any}
	self.event_positions = {}
	---@type {[rizu.VirtualInputEventId]: any}
	self.event_values = {}

	self.event = VirtualInputEvent(0)
end

function BottomNotesHandler:update()
	local active_notes = self.active_notes
	local event_columns = self.event_columns
	local event_positions = self.event_positions
	local event_values = self.event_values
	local event = self.event

	for _, note in ipairs(active_notes:getNotes()) do
		if note.is_bottom then
			---@type any
			local matching_value = false
			for id, value in pairs(event_values) do
				if value then
					event:new(id, event_values[id], event_columns[id], event_positions[id])
					if note:match(event) then
						matching_value = value
						break
					end
				end
			end
			note:input(matching_value)
		end
	end
end

---@param event rizu.VirtualInputEvent
function BottomNotesHandler:receive(event)
	local event_columns = self.event_columns
	local event_positions = self.event_positions
	local event_values = self.event_values

	local value = event.value
	if value ~= nil then
		event_values[event.id] = value
	end

	event_columns[event.id] = event.column
	event_positions[event.id] = event.pos

	if event.value == false then
		event_columns[event.id] = nil
		event_positions[event.id] = nil
		event_values[event.id] = nil
	end
end

---@param column integer
---@return boolean
function BottomNotesHandler:isColumnPressed(column)
	for id, col in pairs(self.event_columns) do
		if col == column and self.event_values[id] then
			return true
		end
	end
	return false
end

return BottomNotesHandler
