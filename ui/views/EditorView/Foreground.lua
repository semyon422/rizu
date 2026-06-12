local just = require("just")
local gfx_util = require("gfx_util")
local spherefonts = require("sphere.assets.fonts")

local Layout = require("ui.views.EditorView.Layout")

---@param self table
local function Hotkeys(self)
	local editorModel = self.game.editorModel
	local noteManager = editorModel.noteManager
	local notificationModel = self.game.notificationModel

	local kp = just.keypressed
	if editorModel.isEditorCommandRequested() then
		if kp("s") then
			self.game.editorController:save()
			notificationModel:notify("saved")
		elseif kp("c") then
			noteManager:copyNotes()
			notificationModel:notify("copy " .. #noteManager.copiedNotes .. " notes")
		elseif kp("x") then
			noteManager:copyNotes(true)
			notificationModel:notify("cut " .. #noteManager.copiedNotes .. " notes")
		elseif kp("v") then
			noteManager:pasteNotes()
			notificationModel:notify("paste " .. #noteManager.copiedNotes .. " notes")
		elseif kp("h") then
			noteManager:flipNotes()
			notificationModel:notify("flip")
		elseif kp("z") then
			editorModel:undo()
			notificationModel:notify("undo")
		elseif kp("y") then
			editorModel:redo()
			notificationModel:notify("redo")
		end
	end

	if kp("delete") then
		local deleted = noteManager:deleteNotes()
		notificationModel:notify("delete " .. deleted .. " notes")
	end
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

	gfx_util.printFrame(self.game.editorModel.session.patterns_analyzed, 0, 0, w, h, "left", "top")
end

return function(self)
	Notification(self)
	Hotkeys(self)
	PatternsAnalyzed(self)
end
