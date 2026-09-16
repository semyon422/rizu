local View = require("gui.View")
local FlowContainer = require("gui.layout.FlowContainer")
local Label = require("ui.views.Label")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local PauseButton = require("ui.screens.gameplay.PauseButton")

---@class ui.screens.gameplay.PauseOverlay : gui.View
---@operator call: ui.screens.gameplay.PauseOverlay
local PauseOverlay = View + {}

---@param localization ui.localization.Localization
---@param on_continue fun()
---@param on_restart fun()
---@param on_leave fun()
function PauseOverlay:new(localization, on_continue, on_restart, on_leave)
	View.new(self)
	self:anchorFill(0, 0, 0, 0)
	self:setVisible(false)
	self:setOpacity(0)
	self.handles_mouse_input = true

	local title = self:add(Label({
		font_name = "bold",
		font_size = 96,
		text = localization:get("gameplay.pause.title"),
		align = "center",
	}))
	title:setAlignment(0.5, 0):addPosition(0, 72)

	local actions = self:add(FlowContainer({direction = "column", gap = 16, align = 0.5}))
	actions:add(PauseButton(localization:get("gameplay.pause.continue"), on_continue, "continue"))
	actions:add(PauseButton(localization:get("gameplay.pause.restart"), on_restart, "restart"))
	actions:add(PauseButton(localization:get("gameplay.pause.leave"), on_leave, "leave"))
	actions:fitContent():setAlignment(0.5, 0.5):addPosition(0, 58)
end

---@param alpha number
function PauseOverlay:setReveal(alpha)
	alpha = math.max(0, math.min(1, alpha))
	self:clearTransforms("opacity")
	self:setOpacity(alpha)
	self:setVisible(alpha > 0)
end

function PauseOverlay:hide()
	self:setReveal(0)
end

---@return boolean handled
function PauseOverlay:onMouseDown()
	return true
end

---@return boolean handled
function PauseOverlay:onMouseUp()
	return true
end

---@return boolean handled
function PauseOverlay:onMouseClick()
	return true
end

---@return boolean handled
function PauseOverlay:onScroll()
	return true
end

function PauseOverlay:draw()
	-- Multiply blending applies the source RGB even as the View opacity approaches
	-- zero, so it cannot participate correctly in the resume fade. Alpha blending
	-- lets Painter's inherited opacity fade the entire backdrop uniformly.
	Painter.setColorTable({0.025, 0.09, 0.20, 0.88})
	Resources.sprites.pixel:draw(0, 0, 0, self.width, self.height)

	Painter.setColorTable({0.04, 0.18, 0.42, 0.35})
	Resources.sprites.pixel:draw(0, 0, 0, self.width, self.height)
end

return PauseOverlay
