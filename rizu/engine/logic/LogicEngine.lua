local class = require("class")
local table_util = require("table_util")
local LogicNoteFactory = require("rizu.engine.logic.LogicNoteFactory")

---@class rizu.LogicEngine
---@operator call: rizu.LogicEngine
local LogicEngine = class()

---@param logic_info rizu.LogicInfo
function LogicEngine:new(logic_info)
	self.logic_info = logic_info
	self.input_note_factory = LogicNoteFactory(logic_info)

	-- Must be constant
	---@type rizu.LogicNote[]
	self.active_notes = {}

	self:setNotes({})
end

---@param chart chart.Chart
function LogicEngine:load(chart)
	local input_note_factory = self.input_note_factory

	---@type rizu.LogicNote[]
	local notes = {}
	for i, linked_note in ipairs(chart.notes:getLinkedNotes()) do
		local note = input_note_factory:getNote(linked_note)
		table.insert(notes, note)
	end

	self:setNotes(notes)
end

---@param notes rizu.LogicNote[]
function LogicEngine:setNotes(notes)
	self.notes = notes
	table.sort(notes)

	-- The *only* reason to process columns separately
	-- is to process spam (clear->clear) and keysounds for early notes.
	---@type {[chart.Column]: rizu.LogicNote[]}
	local column_notes = {}
	self.column_notes = column_notes

	for i, note in ipairs(notes) do
		note.index = i

		local column = note:getColumn()
		column_notes[column] = column_notes[column] or {}
		table.insert(column_notes[column], note)
	end

	---@type {[chart.Column]: integer}
	local column_note_indexes = {}
	self.column_note_indexes = column_note_indexes

	for column in pairs(column_notes) do
		column_note_indexes[column] = 1
	end

	table_util.clear(self.active_notes)

	---@type {[rizu.LogicNote]: true}
	self.tracked_notes = {}

	---@type {[chart.LinkedNote]: rizu.LogicNote?}
	local linked_to_logic = {}
	for _, logic_note in ipairs(notes) do
		linked_to_logic[logic_note.linked_note] = logic_note
	end
	self.linked_to_logic = linked_to_logic
end

---@return integer
function LogicEngine:getActiveNotesCount()
	return #self.active_notes
end

---@return rizu.LogicNote[]
function LogicEngine:getActiveNotes()
	return self.active_notes
end

---@param target_time number?
function LogicEngine:updateActiveNotes(target_time)
	local column_notes = self.column_notes
	local column_note_indexes = self.column_note_indexes
	local active_notes = self.active_notes
	local tracked_notes = self.tracked_notes
	local logic_info = self.logic_info

	local old_time = logic_info.time
	if target_time then
		logic_info.time = target_time
	end

	for column, notes in pairs(column_notes) do
		local idx = column_note_indexes[column]
		while idx <= #notes do
			local note = notes[idx]

			if not tracked_notes[note] then
				table.insert(active_notes, note)
				tracked_notes[note] = true
			end

			if note:isEarly() then
				break
			else
				idx = idx + 1
			end
		end
		column_note_indexes[column] = idx
	end

	if target_time then
		logic_info.time = old_time
	end
end

function LogicEngine:processActiveNotes()
	local active_notes = self.active_notes
	for _, note in ipairs(active_notes) do
		if note:isActive() then
			note:update()
		end
	end
end

function LogicEngine:filterActiveNotes()
	local active_notes = self.active_notes
	local tracked_notes = self.tracked_notes

	-- Efficient O(N) in-place filtering
	local n = #active_notes
	local j = 1
	for i = 1, n do
		local note = active_notes[i]
		if note:isActive() then
			if i ~= j then
				active_notes[j] = note
			end
			j = j + 1
		else
			tracked_notes[note] = nil
		end
	end
	for i = n, j, -1 do
		active_notes[i] = nil
	end
end

function LogicEngine:update()
	self:updateActiveNotes()
	self:processActiveNotes()
	self:filterActiveNotes()
end

return LogicEngine
