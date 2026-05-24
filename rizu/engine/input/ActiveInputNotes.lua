local class = require("class")
local table_util = require("table_util")
local InputNote = require("rizu.engine.input.notes.InputNote")

---@class rizu.ActiveInputNotes
---@operator call: rizu.ActiveInputNotes
local ActiveInputNotes = class()

---@param logic_notes rizu.LogicNote[]
function ActiveInputNotes:new(logic_notes)
	self.logic_notes = logic_notes

	---@type rizu.InputNote[]
	self.input_notes = {}

	---@type {[rizu.LogicNote]: rizu.InputNote}
	self.cache = {}
end

---@param input_map {[chart.Column]: integer}
function ActiveInputNotes:setInputMap(input_map)
	self.input_map = input_map
end

---@return boolean
function ActiveInputNotes:hasAny()
	return not not next(self.logic_notes)
end

---@private
function ActiveInputNotes:update()
	local input_notes = self.input_notes
	local cache = self.cache
	local input_map = assert(self.input_map, "missing input map")

	table_util.clear(input_notes)

	---@type {[rizu.LogicNote]: true}
	local current_logic_notes = {}

	for i, logic_note in ipairs(self.logic_notes) do
		current_logic_notes[logic_note] = true
		local input_note = cache[logic_note]
		if not input_note then
			input_note = InputNote(logic_note, input_map)
			cache[logic_note] = input_note
		end
		input_notes[i] = input_note
	end

	-- Clean up cache to prevent memory leak
	for logic_note in pairs(cache) do
		if not current_logic_notes[logic_note] then
			cache[logic_note] = nil
		end
	end
end

function ActiveInputNotes:getNotes()
	self:update()
	return self.input_notes
end

return ActiveInputNotes
