local Painter = require("gui.Painter")
local View = require("gui.View")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")
local SpringValue = require("gui.anim.SpringValue")

---@class ui.screens.gameplay.ClearStatus : gui.View
---@operator call: ui.screens.gameplay.ClearStatus
local ClearStatus = View + {}

function ClearStatus:new()
	View.new(self)
	self.font = Resources.getFont("bold", 48)
	self.text = ""
	self:setHeight(68)
	self.color = Colors.text
	self.spring = SpringValue({value = 0})
end

function ClearStatus:load()
	self:fillWidth(0, 0)
end

---@param text string
---@param color gui.Color
function ClearStatus:bind(text, color)
	self.text = text
	self.color = color
end

function ClearStatus:show()
	self.spring:snap(0)
	self.spring:set(1)
end

function ClearStatus:hide()
	self.spring:snap(0)
end

---@param dt number
function ClearStatus:update(dt)
	self.spring:update(dt)
end

function ClearStatus:draw()
	local progress = self.spring:get()
	if progress == 0 then
		return
	end

	local height = self.height * progress
	Painter.setColorTable(Colors.panel)
	love.graphics.rectangle("fill", 0, (self.height - height) / 2, self.width, height)
	love.graphics.setFont(self.font)
	Painter.setColorTable(self.color)
	love.graphics.printf(self.text, 0, (self.height - self.font:getHeight()) / 2, self.width, "center")
end

return ClearStatus
