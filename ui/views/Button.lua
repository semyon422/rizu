local View = require("gui.View")
local Resources = require("ui.Resources")
local SpringValue = require("gui.anim.SpringValue")

---@class ui.views.Button : gui.View
---@operator call: ui.views.Button
---@field text string
---@field on_click fun()?
---@field font love.Font
local Button = View + {}

---@param text string
---@param on_click fun()?
function Button:new(text, on_click)
	View.new(self)
	self.text = text
	self.on_click = on_click
	self.font = Resources.getFont("bold", 24)
	self:setSize(320, 64)
	self:setPivot(0.5, 0.5)
	self.handles_mouse_input = true
	self.hover = SpringValue()
end

---@param e gui.MouseClickEvent
function Button:onMouseClick(e)
	if e.button ~= 1 then
		return
	end
	if self.on_click then
		self.on_click()
		self:scaleTo(1, 1, 0.1, "InCubic")
	end
	return true
end

function Button:onMouseDown(e)
	if e.button == 1 then
		self:scaleTo(1.1, 1.1, 0.2, "OutSine")
		return true
	end
end

function Button:onMouseUp(e)
	if e.button == 1 then
		self:scaleTo(1, 1, 0.1, "InCubic")
		return true
	end
end

function Button:update(dt)
	self.hover:update(dt)
	self.hover:set(self.mouse_over and 1 or 0)
end

function Button:draw()
	local lg = love.graphics
	local r, g, b, a = 0.16, 0.18, 0.22, self.effective_opacity

	if self.mouse_over then
		r, g, b = 0.25, 0.42, 0.65
	end
	if self.pressed then
		r, g, b = 0.12, 0.30, 0.50
	end

	lg.setColor(r, g, b, 0.96 * a)
	lg.rectangle("fill", 0, 0, self.width, self.height, 6, 6)
	lg.setColor(0.55, 0.70, 0.90, a)
	lg.setLineWidth(2)
	lg.rectangle("line", 1, 1, self.width - 2, self.height - 2, 6, 6)
	lg.setColor(1, 1, 1, a)
	lg.setFont(self.font)
	lg.printf(self.text, 0, (self.height - self.font:getHeight()) / 2, self.width, "center")
end

return Button
