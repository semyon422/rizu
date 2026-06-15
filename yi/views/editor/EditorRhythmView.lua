local RhythmView = require("sphere.views.RhythmView")
local gfx_util = require("gfx_util")

---@class yi.views.editor.EditorRhythmView: sphere.RhythmView
---@operator call: yi.views.editor.EditorRhythmView
local EditorRhythmView = RhythmView + {}

---@param f function
function EditorRhythmView:processNotes(f)
	local editorModel = self.game.editorModel
	for _, note in ipairs(editorModel.visualEngine.notes) do
		f(self, note)
	end
	for _, note in ipairs(editorModel.noteService:getGrabbedNotes()) do
		f(self, note)
	end
end

---@param tf love.Transform
---@param w number
---@param h number
---@return boolean
local function isMouseOver(tf, w, h)
	local x, y = love.graphics.inverseTransformPoint(love.mouse.getPosition())
	x, y = tf:inverseTransformPoint(x, y)
	return x >= 0 and x <= w and y >= 0 and y <= h
end

---@param rect number[]?
---@param tf love.Transform
---@param w number
---@param h number
---@return boolean
local function isSelectedByRect(rect, tf, w, h)
	if not rect then
		return false
	end

	local x0, y0 = tf:transformPoint(0, 0)
	local x1, y1 = tf:transformPoint(w, h)
	local noteLeft = math.min(x0, x1)
	local noteRight = math.max(x0, x1)
	local noteTop = math.min(y0, y1)
	local noteBottom = math.max(y0, y1)

	local rectLeft = math.min(rect[1], rect[3])
	local rectRight = math.max(rect[1], rect[3])
	local rectTop = math.min(rect[2], rect[4])
	local rectBottom = math.max(rect[2], rect[4])

	return noteLeft <= rectRight and noteRight >= rectLeft and noteTop <= rectBottom and noteBottom >= rectTop
end

---@param noteView sphere.NoteView
---@param note rizu.editor.EditorNote
---@param rect number[]?
function EditorRhythmView:reportShortNoteInteraction(noteView, note, rect)
	local headPart = noteView:getNotePart("Head")
	if not headPart:getSpriteBatch() then
		return
	end

	local w, h = headPart:getDimensions()
	local tf = gfx_util.transform(noteView:getTransformParams())
	note:setPartInteractionState("body", isMouseOver(tf, w, h), isSelectedByRect(rect, tf, w, h))
end

---@param noteView sphere.NoteView
---@param note rizu.editor.EditorNote
---@param rect number[]?
function EditorRhythmView:reportLongNoteInteraction(noteView, note, rect)
	local headPart = noteView:getNotePart("Head")
	local bodyPart = noteView:getNotePart("Body")
	local tailPart = noteView:getNotePart("Tail")

	if headPart:getSpriteBatch() then
		local w, h = headPart:getDimensions()
		local tf = gfx_util.transform(noteView:getHeadTransformParams())
		note:setPartInteractionState("head", isMouseOver(tf, w, h), isSelectedByRect(rect, tf, w, h))
	end

	if tailPart:getSpriteBatch() then
		local w, h = tailPart:getDimensions()
		local tf = gfx_util.transform(noteView:getTailTransformParams())
		note:setPartInteractionState("tail", isMouseOver(tf, w, h), isSelectedByRect(rect, tf, w, h))
	end

	if bodyPart:getSpriteBatch() then
		local tf = gfx_util.transform(noteView:getBodyTransformParams())
		local _, _, w, h = noteView.bodyQuad:getViewport()
		note:setPartInteractionState("body", isMouseOver(tf, w, h), isSelectedByRect(rect, tf, w, h))
	end
end

---@param noteView sphere.NoteView
---@param note rizu.editor.EditorNote
function EditorRhythmView:reportNoteInteraction(noteView, note)
	note:clearInteractionState()
	local rect = self.game.editorModel:getSelectionState():getRect()
	if note.noteType == "ShortNote" then
		self:reportShortNoteInteraction(noteView, note, rect)
	elseif note.noteType == "LongNote" then
		self:reportLongNoteInteraction(noteView, note, rect)
	end
end

---@param note rizu.editor.EditorNote
function EditorRhythmView:drawNote(note)
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
		self:reportNoteInteraction(noteView, note)
	end
end

return EditorRhythmView
