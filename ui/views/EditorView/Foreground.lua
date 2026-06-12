local just = require("just")
local gfx_util = require("gfx_util")
local spherefonts = require("sphere.assets.fonts")

local Layout = require("ui.views.EditorView.Layout")

---@param self table
local function Hotkeys(self)
	self.editorViewServices.actionService:handleHotkeys({
		editorController = self.game.editorController,
		editorModel = self.game.editorModel,
		notificationModel = self.game.notificationModel,
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
