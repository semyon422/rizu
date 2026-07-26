local View = require("gui.View")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")

---@class ui.views.OverlayBackground : gui.View
---@operator call: ui.views.OverlayBackground
---@field on_click fun()
local OverlayBackground = View + {}

---@param on_click fun()
function OverlayBackground:new(on_click)
	View.new(self)
	self.on_click = on_click
	self:anchorFill(0, 0, 0, 0)
	self:setOpacity(0)
	self:setVisible(false)
end

function OverlayBackground:show()
	self.handles_mouse_input = true
	self:setVisible(true)
	self:transformTo("opacity", 0.2, 0.3, "OutQuart")
end

function OverlayBackground:hide()
	self.handles_mouse_input = false
	self:transformTo("opacity", 0, 0.2, "InCubic", function()
		self:setVisible(false)
	end)
end

---@return boolean handled
function OverlayBackground:onMouseDown()
	return true
end

---@return boolean handled
function OverlayBackground:onMouseUp()
	return true
end

---@return boolean handled
function OverlayBackground:onMouseClick()
	self.on_click()
	return true
end

---@return boolean handled
function OverlayBackground:onScroll()
	return true
end

function OverlayBackground:draw()
	Painter.setColorRgb(1, 0.69, 0.87)
	love.graphics.setBlendMode("add")
	Resources.sprites.pixel:draw(0, 0, 0, self.width, self.height)
	love.graphics.setBlendMode("alpha")
end

return OverlayBackground
