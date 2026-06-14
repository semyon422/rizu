local RhythmView = require("sphere.views.RhythmView")
local EditorPlayfieldHitTestService = require("rizu.editor.EditorPlayfieldHitTestService")
local EditorPlayfieldInputService = require("rizu.editor.EditorPlayfieldInputService")
local EditorPlayfieldInputStateService = require("rizu.editor.EditorPlayfieldInputStateService")
local EditorPlayfieldService = require("rizu.editor.EditorPlayfieldService")
local gfx_util = require("gfx_util")

---@class rizu.editor.EditorRhythmView: sphere.RhythmView
---@operator call: rizu.editor.EditorRhythmView
local EditorRhythmView = RhythmView + {}

local playfieldService = EditorPlayfieldService()
local playfieldInputService = EditorPlayfieldInputService({
	playfieldService = playfieldService,
})
local playfieldInputStateService = EditorPlayfieldInputStateService()
local playfieldHitTestService = EditorPlayfieldHitTestService()

---@param note sphere.GraphicalNote
---@param context rizu.editor.EditorPlayfieldContext
---@param inputState rizu.editor.EditorRhythmInputState
function EditorRhythmView:processNote(note, context, inputState)
	local editorModel = self.game.editorModel

	local mouseTime = editorModel:getMouseTime()
	local noteInput = playfieldHitTestService:getNoteInput(note, mouseTime, inputState)
	if noteInput then
		playfieldInputService:handleNoteInput(context, noteInput)
	end
end

function EditorRhythmView:draw()
	local editorModel = self.game.editorModel
	local playfieldContext = editorModel.context:getViewContext()
	local layer = editorModel.layer
	local noteSkin = self.game.noteSkinModel.noteSkin

	if not layer.points:getFirstPoint() then
		return
	end

	love.graphics.replaceTransform(gfx_util.transform(self.transform))

	local Head = noteSkin.notes.ShortNote.Head
	local inputState = playfieldInputStateService:getState()

	if playfieldService:isNotesActive(playfieldContext) then
		if playfieldService:canAddNote(playfieldContext) then
			for i = 1, noteSkin.columnsCount do
				local h = noteSkin:getValue(Head.h, 1)
				local columnInput = playfieldHitTestService:getColumnInput(
					noteSkin,
					Head,
					i,
					editorModel:getMouseTime(h / 2),
					inputState
				)
				playfieldInputService:handleColumnInput(playfieldContext, columnInput)
			end
		elseif playfieldService:isSelectTool(playfieldContext) then
			playfieldInputService:handleSelectInput(
				playfieldContext,
				playfieldHitTestService:getSelectInput(inputState)
			)
		end
		local selectRect = playfieldService:getSelectionRect(playfieldContext)
		if selectRect then
			local x, y, x1, y1 = unpack(selectRect)
			love.graphics.push("all")
			love.graphics.setColor(1, 1, 1, 1)
			love.graphics.rectangle("line", x, y, x1 - x, y1 - y)
			love.graphics.setColor(1, 1, 1, 0.2)
			love.graphics.rectangle("fill", x, y, x1 - x, y1 - y)
			love.graphics.pop()
		end
	end

	RhythmView.draw(self)

	if not playfieldService:isNotesActive(playfieldContext) then
		return
	end

	for _, note in ipairs(editorModel.visualEngine.notes) do
		self:processNote(note, playfieldContext, inputState)
	end
	playfieldInputService:handleReleaseInput(
		playfieldContext,
		playfieldHitTestService:getReleaseInput(editorModel:getMouseTime(), inputState)
	)
end

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

return EditorRhythmView
