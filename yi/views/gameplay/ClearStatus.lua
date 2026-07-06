local View = require("gui.View")
local Resources = require("yi.Resources")
local Colors = require("yi.Colors")
local SpringValue = require("gui.anim.SpringValue")

---@class yi.views.gameplay.ClearStatus : gui.View
---@operator call: yi.views.gameplay.ClearStatus
local ClearStatus = View + {}

function ClearStatus:new()
	View.new(self)

	self.font48 = Resources.getFont("bold", 48)
	self:setHeight(68)
	self.text = ""
	self.color = {1, 1, 1, 1}
	self.spring = SpringValue({value = 0})
	self.scissor_x = 0
	self.scissor_y = 0
	self.scissor_w = 0
	self.scissor_h = 0
end

function ClearStatus:applyLayout()
	self:setWidth(self.box.width)
	View.applyLayout(self)
end

---@param text string
---@param color gui.Color
function ClearStatus:bind(text, color)
	self.text = text
	self.color = color
	self.text_ox = self.font48:getWidth(self.text) / 2
	self.text_oy = self.font48:getHeight() / 2

	local x, y = self.transform:transformPoint(0, 0)
	local w, h = self.transform:transformPoint(self.width, self.height)
	self.scissor_x, self.scissor_y = x, y
	self.scissor_w, self.scissor_h = w - x, h - y
end

function ClearStatus:show()
	self.spring:snap(0)
	self.spring:set(1)
end

function ClearStatus:hide()
	self.spring:snap(0)
end

function ClearStatus:update(dt)
	self.spring:update(dt)
end

function ClearStatus:draw()
	local a = self.spring:get()

	if a == 0 then
		return
	end

	local x, y, w, h = self.scissor_x, self.scissor_y, self.scissor_w, self.scissor_h

	love.graphics.setScissor(x, y + (h / 2) * (1 - a), w, h * a)
	love.graphics.setColor(Colors.panel)
	love.graphics.draw(Resources.atlas, Resources.quads.pixel, 0, 0, 0, self.width, self.height)
	love.graphics.setFont(self.font48)
	love.graphics.setColor(self.color)
	love.graphics.print(self.text, self.width / 2, self.height / 2, 0, 1, 1, self.text_ox, self.text_oy)
	love.graphics.setScissor()
end

return ClearStatus
