local just = require("just")
local gfx_util = require("gfx_util")
local spherefonts = require("sphere.assets.fonts")

local Layout = require("ui.views.EditorView.Layout")

---@param self table
local function Hotkeys(self)
	local editorController = self.game.editorController
	local editorModel = self.game.editorModel
	local notificationModel = self.game.notificationModel
	local noteService = editorModel.noteService

	self.editorViewServices.actionService:handleHotkeys({
		save = function()
			editorController:save()
		end,
		copyNotes = function(_, cut)
			noteService:copyNotes(cut)
		end,
		pasteNotes = function()
			noteService:pasteNotes()
		end,
		flipNotes = function()
			noteService:flipNotes()
		end,
		undo = function()
			editorModel:undo()
		end,
		redo = function()
			editorModel:redo()
		end,
		deleteNotes = function()
			return noteService:deleteNotes()
		end,
		getCopiedNoteCount = function()
			return #noteService:getCopiedNotes()
		end,
		notify = function(_, message)
			notificationModel:notify(message)
		end,
		isEditorCommandRequested = function()
			return editorModel.isEditorCommandRequested()
		end,
		keypressed = just.keypressed,
	})
end

---@param self table
local function Notification(self)
	local w, h = Layout:move("header")

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setFont(spherefonts.get("Noto Sans", 24))
	gfx_util.printFrame(self.game.notificationModel.message, 0, 0, w, h, "center", "center")
end

---@param self table
local function PatternsAnalyzed(self)
	local w, h = Layout:move("header")

	love.graphics.translate(w - 250, 0)

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setFont(spherefonts.get("Noto Sans Mono", 22))

	gfx_util.printFrame(self.game.editorModel:getPatternsAnalyzed(), 0, 0, w, h, "left", "top")
end

return function(self)
	Notification(self)
	Hotkeys(self)
	PatternsAnalyzed(self)
end
