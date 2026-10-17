local class = require("class")
local BottomNotesHandler = require("rizu.engine.input.BottomNotesHandler")
local InputPauser = require("rizu.engine.input.InputPauser")

---@class rizu.InputEngine
---@operator call: rizu.InputEngine
local InputEngine = class()

InputEngine.nearest = false

---@param active_notes rizu.ActiveInputNotes
function InputEngine:new(active_notes)
	self.active_notes = active_notes

	self.bottom_notes_handler = BottomNotesHandler(active_notes)

	self.input_pauser = InputPauser()

	---@type {[rizu.VirtualInputEventId]: rizu.InputNote}
	self.event_catches = {}
	---@type {[rizu.InputNote]: rizu.VirtualInputEventId}
	self.catched_notes = {}
end

---@param event rizu.VirtualInputEvent
---@return integer
function InputEngine:getNotesMaxPriority(event)
	local priority = -math.huge

	for _, note in ipairs(self.active_notes:getNotes()) do
		if not note.is_bottom and note:match(event) then
			priority = math.max(priority, note:getPriority())
		end
	end

	return priority
end

---@param note rizu.InputNote
---@param value any
---@return rizu.InputNote?
---@return boolean? catched
function InputEngine:input_note(note, value)
	if not self.input_pauser.paused then
		note:input(value)
	end
end

function InputEngine:update()
	if not self.input_pauser.paused then
		self.bottom_notes_handler:update()
	end
end

---@param event rizu.VirtualInputEvent
---@param note rizu.InputNote
---@return rizu.InputNote?
---@return boolean? catched
function InputEngine:handle_catched_note(event, note)
	local matched = note:match(event)
	if matched and event.value ~= nil then
		self:input_note(note, event.value)
		return note, not not event.value
	elseif not matched then
		self:input_note(note, false)
		return note, false
	end

	return note, true
end

---@param event rizu.VirtualInputEvent
---@return rizu.InputNote?
---@return boolean? catched
function InputEngine:receive_catched(event)
	local active_notes = self.active_notes
	local catched_notes = self.catched_notes

	local notes = active_notes:getNotes()
	if not notes[1] then
		return
	end

	local catch_note = self.event_catches[event.id]
	for _, note in ipairs(notes) do
		if note == catch_note then
			return self:handle_catched_note(event, note)
		end
	end

	local value = event.value
	if not value then
		return
	end

	if self.input_pauser.paused then
		for _, note in ipairs(notes) do
			if self.input_pauser.paused_notes[note] ~= nil and not catched_notes[note] and note:match(event) then
				return note, true
			end
		end
	end

	local priority = self:getNotesMaxPriority(event)

	if not self.nearest then
		for _, note in ipairs(notes) do
			if not note.is_bottom and note:getPriority() == priority and note:match(event) and not catched_notes[note] then
				self:input_note(note, value)
				return note, not not value
			end
		end
		return
	end

	---@type rizu.InputNote?
	local nearest_note
	local nearest_time = math.huge
	for _, note in ipairs(notes) do
		local time = math.abs(note:getDeltaTime())
		if not note.is_bottom and note:getPriority() == priority and note:match(event) and not catched_notes[note] and time < nearest_time then
			nearest_time = time
			nearest_note = note
		end
	end

	if not nearest_note then
		return
	end

	self:input_note(nearest_note, value)
	return nearest_note, not not value
end

---@param event rizu.VirtualInputEvent
---@return rizu.InputNote?
---@return boolean? catched
function InputEngine:receive(event)
	self.bottom_notes_handler:receive(event)
	self.input_pauser:receive(event.id, event.value)

	local note, catched = self:receive_catched(event)

	local old_note = self.event_catches[event.id]
	if old_note then
		self.event_catches[event.id] = nil
		self.catched_notes[old_note] = nil
	end

	if note and catched then
		self.event_catches[event.id] = note
		self.catched_notes[note] = event.id
	end

	return note, catched
end

function InputEngine:pause()
	self.input_pauser:pause(self.catched_notes)
end

function InputEngine:resume()
	self.input_pauser:resume(self.catched_notes)
end

---@param column integer
---@return boolean
function InputEngine:isColumnPressed(column)
	return self.bottom_notes_handler:isColumnPressed(column)
end

return InputEngine
