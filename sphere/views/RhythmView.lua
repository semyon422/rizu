local class = require("class")
local NoteViewFactory = require("sphere.views.RhythmView.NoteViewFactory")
local gfx_util = require("gfx_util")

---@class sphere.RhythmView
---@operator call: sphere.RhythmView
---@field game sphere.GameController
---@field isNotesView boolean?
local RhythmView = class()

RhythmView.mode = "default"

---@param f function
function RhythmView:processNotes(f)
	local visual_engine = self.game.rhythm_engine.visual_engine
	for _, note in ipairs(visual_engine.visible_notes) do
		f(self, note)
	end
end

---@param note sphere.GraphicalNote
---@return sphere.NoteView?
function RhythmView:getNoteView(note)
	return NoteViewFactory:getNoteView(note, self.mode)
end

---@param note sphere.GraphicalNote
function RhythmView:fillChord(note)
	local noteSkin = self:getNoteSkin()
	local noteView = self:getNoteView(note)
	if not noteView then
		return
	end

	noteView.noteSkin = noteSkin
	noteView.graphicalNote = note
	noteView.chords = self.chords

	for _, column in ipairs(noteSkin:getColumns(note)) do
		if column and column <= noteSkin.columnsCount and noteView.fillChords and noteView:isVisible() then
			noteView:fillChords(self.chords, column)
		end
	end
end

---@param note sphere.GraphicalNote
function RhythmView:drawNote(note)
	local noteSkin = self:getNoteSkin()
	local noteView = self:getNoteView(note)
	if not noteView then
		return
	end

	for _, column in ipairs(noteSkin:getColumns(note)) do
		noteView.column = column
		noteView.chords = self.chords
		noteView.noteSkin = noteSkin
		noteView.graphicalNote = note
		noteView.rhythmView = self
		noteView.resource_loader = self.game.resource_loader

		noteView:draw()
	end
end

---@param note sphere.GraphicalNote
function RhythmView:drawSelected(note)
	local noteSkin = self:getNoteSkin()
	local noteView = self:getNoteView(note)
	if not (noteView and noteView.drawSelected and note.selected) then
		return
	end

	for _, column in ipairs(noteSkin:getColumns(note)) do
		noteView.column = column
		noteView.chords = self.chords
		noteView.noteSkin = noteSkin
		noteView.graphicalNote = note
		noteView.rhythmView = self
		noteView:drawSelected()
	end
end

---@param note chart.Note
function RhythmView:pressNote(note) end

---@return sphere.NoteSkin
function RhythmView:getNoteSkin()
	return self.game.noteSkinModel.noteSkin
end

function RhythmView:draw()
	love.graphics.replaceTransform(gfx_util.transform(self.transform))
	love.graphics.setColor(1, 1, 1, 1)

	self.chords = {}
	if self.mode == "default" then
		self:processNotes(self.fillChord)
	end

	self:processNotes(self.drawNote)

	local noteSkin = self:getNoteSkin()
	local blendModes = noteSkin.blendModes
	local spriteBatches = noteSkin.data.spriteBatches
	for _, spriteBatch in ipairs(spriteBatches) do
		local key = spriteBatches[spriteBatch]
		local blendMode = blendModes[key]
		if blendMode then
			love.graphics.setBlendMode(blendMode[1], blendMode[2])
		end
		love.graphics.draw(spriteBatch)
		spriteBatch:clear()
		if blendMode then
			love.graphics.setBlendMode("alpha")
		end
	end

	self:processNotes(self.drawSelected)
end

return RhythmView
