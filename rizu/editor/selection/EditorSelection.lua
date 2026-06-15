local class = require("class")

---@class rizu.editor.EditorSelection
---@operator call: rizu.editor.EditorSelection
---@field notes {[chart.Note]: rizu.editor.EditorNote}
local EditorSelection = class()

function EditorSelection:new()
	self.notes = {}
	self.selecting = false
end

---@param visibleNotes rizu.editor.EditorNote[]
function EditorSelection:clearVisible(visibleNotes)
	for _, note in ipairs(visibleNotes) do
		note.selected = false
	end
end

---@param visibleNotes rizu.editor.EditorNote[]
function EditorSelection:clear(visibleNotes)
	self:clearVisible(visibleNotes)
	self.notes = {}
end

---@param visibleNotes rizu.editor.EditorNote[]
function EditorSelection:start(visibleNotes)
	self:clear(visibleNotes)
	self.selecting = true
end

function EditorSelection:finish()
	self.selecting = false
end

---@param note rizu.editor.EditorNote?
---@param keepOthers boolean?
---@param visibleNotes rizu.editor.EditorNote[]
function EditorSelection:select(note, keepOthers, visibleNotes)
	if not note then
		self:clear(visibleNotes)
		return
	end

	if not note.selected then
		if not keepOthers then
			self:clear(visibleNotes)
		end
		note.selected = true
		self.notes[note.startNote] = note
		return
	end

	if not keepOthers then
		return
	end

	note.selected = false
	self.notes[note.startNote] = nil
end

---@param visibleNotes rizu.editor.EditorNote[]
function EditorSelection:updateVisible(visibleNotes)
	for _, note in ipairs(visibleNotes) do
		if note.selecting then
			note.selected = true
			self.notes[note.startNote] = note
		elseif self.selecting then
			note.selected = false
			self.notes[note.startNote] = nil
		end
	end
end

return EditorSelection
