local RhythmView = require("sphere.views.RhythmView")
local just = require("just")
local gfx_util = require("gfx_util")

---@class rizu.editor.EditorRhythmView: sphere.RhythmView
---@operator call: rizu.editor.EditorRhythmView
local EditorRhythmView = RhythmView + {}

---@param note sphere.GraphicalNote
function EditorRhythmView:processNote(note)
	local editorModel = self.game.editorModel
	local noteService = editorModel.noteService
	local visualEngine = editorModel.visualEngine

	local mouseTime = editorModel:getMouseTime()
	if note.noteType == "ShortNote" then
		local over = just.mouse_over(note, note.over, "mouse")
		if over then
			if just.mousepressed(1) then
				visualEngine:selectNote(note)
				noteService:grabNotes("body", mouseTime)
			elseif just.mousepressed(2) then
				noteService:removeNote(note)
			end
		end
	elseif note.noteType == "LongNote" then
		local bodyOver = just.mouse_over(tostring(note) .. "body", note.bodyOver, "mouse")
		local headOver = just.mouse_over(tostring(note) .. "head", note.headOver, "mouse")
		local tailOver = just.mouse_over(tostring(note) .. "tail", note.tailOver, "mouse")
		if just.mousepressed(1) then
			if bodyOver then
				visualEngine:selectNote(note)
				noteService:grabNotes("body", mouseTime)
			elseif headOver then
				visualEngine:selectNote(note)
				noteService:grabNotes("head", mouseTime)
			elseif tailOver then
				visualEngine:selectNote(note)
				noteService:grabNotes("tail", mouseTime)
			end
		end
		if (bodyOver or headOver or tailOver) and just.mousepressed(2) then
			noteService:removeNote(note)
		end
	end
end

function EditorRhythmView:draw()
	local editorModel = self.game.editorModel
	local noteService = editorModel.noteService
	local layer = editorModel.layer
	local noteSkin = self.game.noteSkinModel.noteSkin
	local editor = self.game.configModel.configs.settings.editor

	if not layer.points:getFirstPoint() then
		return
	end

	love.graphics.replaceTransform(gfx_util.transform(self.transform))

	local Head = noteSkin.notes.ShortNote.Head

	if editorModel.session.state == "notes" then
		if editor.tool == "ShortNote" or editor.tool == "LongNote" then
			for i = 1, noteSkin.columnsCount do
				local x = noteSkin:getValue(Head.x, i)
				local w = noteSkin:getValue(Head.w, i)
				local h = noteSkin:getValue(Head.h, 1)
				local over = just.is_over(w, noteSkin.unit, x, 0)
				over = just.mouse_over("add note" .. i, over, "mouse")
				if over and just.mousepressed(1) then
					local t = editorModel:getMouseTime(h / 2)
					noteService:addNote(t, "key" .. i)
				end
			end
		elseif editor.tool == "Select" then
			local over = just.mouse_over("editor select", true, "mouse")
			if over and just.mousepressed(1) then
				editorModel:selectStart()
			end
		end
		if editorModel.session.selectRect then
			local x, y, x1, y1 = unpack(editorModel.session.selectRect)
			love.graphics.push("all")
			love.graphics.setColor(1, 1, 1, 1)
			love.graphics.rectangle("line", x, y, x1 - x, y1 - y)
			love.graphics.setColor(1, 1, 1, 0.2)
			love.graphics.rectangle("fill", x, y, x1 - x, y1 - y)
			love.graphics.pop()
		end
	end

	RhythmView.draw(self)

	if editorModel.session.state ~= "notes" then
		return
	end

	for _, note in ipairs(editorModel.visualEngine.notes) do
		self:processNote(note)
	end
	if just.mousereleased(1) then
		if next(editorModel.noteService:getGrabbedNotes()) then
			local t = editorModel:getMouseTime()
			noteService:dropNotes(t)
		end
		if editorModel.session.selectRect then
			editorModel:selectEnd()
		end
	end
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
