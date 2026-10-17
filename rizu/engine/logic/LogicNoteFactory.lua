local class = require("class")
local TapLogicNote = require("rizu.engine.logic.notes.TapLogicNote")
local HoldLogicNote = require("rizu.engine.logic.notes.HoldLogicNote")
local SimpleLogicNote = require("rizu.engine.logic.notes.SimpleLogicNote")

---@class rizu.LogicNoteFactory
---@operator call: rizu.LogicNoteFactory
local LogicNoteFactory = class()

---@type {[chart.NoteType]: rizu.LogicNote?}
local notes = {
	tap = TapLogicNote,
	hold = HoldLogicNote,
	laser = HoldLogicNote,
	drumroll = HoldLogicNote,
	mine = SimpleLogicNote,
	shade = SimpleLogicNote,
	fake = SimpleLogicNote,
	sample = SimpleLogicNote,
	sprite = SimpleLogicNote,
}

---@param logic_info rizu.LogicInfo
function LogicNoteFactory:new(logic_info)
	self.logic_info = logic_info
end

---@param note chart.LinkedNote
---@return rizu.LogicNote?
function LogicNoteFactory:getNote(note)
	local Note = notes[note:getType()]
	if not Note then
		return
	end

	return Note(note, self.logic_info)
end

return LogicNoteFactory
