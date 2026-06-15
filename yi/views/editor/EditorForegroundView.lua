local View = require("gui.View")
local gfx_util = require("gfx_util")
local spherefonts = require("sphere.assets.fonts")
local EditorGui = require("yi.views.editor.EditorGui")

local EditorLayout = require("yi.views.editor.EditorLayout")

---@class yi.views.editor.EditorForegroundView: gui.View
---@operator call: yi.views.editor.EditorForegroundView
---@field screen table
---@field gui yi.views.editor.EditorGui
local EditorForegroundView = View + {}

---@param screen table
function EditorForegroundView:new(screen)
	View.new(self)
	self.screen = screen
	self.gui = EditorGui()
	self.handles_keyboard_input = true
	self:setSize(love.graphics.getDimensions())
end

function EditorForegroundView:load()
	self:setSize(love.graphics.getDimensions())
end

---@param e gui.KeyDownEvent
function EditorForegroundView:onKeyDown(e)
	return self.gui:onKeyDown(e)
end

function EditorForegroundView:handleHotkeys()
	local screen = self.screen
	local editorController = screen.game.editorController
	local editorModel = screen.game.editorModel
	local notificationModel = screen.game.notificationModel
	local noteService = editorModel.noteService

	screen.editorViewServices.actionService:handleHotkeys({
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
		keypressed = function(key)
			return self.gui:consumeKey(key)
		end,
	})
end

function EditorForegroundView:drawNotification()
	local screen = self.screen
	local w, h = EditorLayout:move("header")

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setFont(spherefonts.get("Noto Sans", 24))
	gfx_util.printFrame(screen.game.notificationModel.message, 0, 0, w, h, "center", "center")
end

function EditorForegroundView:drawPatternsAnalyzed()
	local screen = self.screen
	local w, h = EditorLayout:move("header")

	love.graphics.translate(w - 250, 0)

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setFont(spherefonts.get("Noto Sans Mono", 22))

	gfx_util.printFrame(screen.game.editorModel:getPatternsAnalyzed(), 0, 0, w, h, "left", "top")
end

function EditorForegroundView:draw()
	self:drawNotification()
	self:handleHotkeys()
	self:drawPatternsAnalyzed()
	self.gui:finishFrame()
end

return EditorForegroundView
