local ModalView = require("ui.ModalView")
local Resources = require("ui.Resources")
local Painter = require("gui.Painter")
local Colors = require("ui.Colors")

---@class ui.modals.config.Config : ui.ModalView
---@operator call: ui.modals.config.Config
local Config = ModalView + {}

function Config:new()
	ModalView.new(self)
	self:setSize(890, 600)
	self:setAlignment(0.5, 0.5)
	self:setPivot(0.5, 0.5)
	self:setScale(0.9, 0.9)
	self:setOpacity(0)
	self:setVisible(false)
end

function Config:show()
	self:setVisible(true)
	self:fadeIn(0.3, "OutCubic")
	self:scaleTo(1, 1, 0.4, "OutQuart")
end

function Config:hide()
	self:scaleTo(0.9, 0.9, 0.24, "InQuart")
	self:transformTo("opacity", 0, 0.2, "InCubic", function()
		self:setVisible(false)
	end)
end

function Config:draw()
	Painter.setColorTable(Colors.panel)
	love.graphics.draw(Resources.atlas, Resources.quads.pixel, 0, 0, 0, self.width, self.height)
end

return Config
