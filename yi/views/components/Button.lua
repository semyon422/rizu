local View = require("yi.views.View")
local Colors = require("yi.Colors")

---@class yi.Button : yi.View
---@overload fun(text: string, on_click: fun()): yi.Button
local Button = View + {}

---@param text string
---@param on_click fun()
function Button:new(text, on_click)
	View.new(self)
	self:setup({
		w = 120,
		h = 32,
		mouse = true,
	})

	self.text = text
	self.on_click = on_click
	self.hovered = false
	self.pressed = false
	self.active = false
end

function Button:load()
	local font = self:getResources():getFont("bold", 16)
	self.text_batch = love.graphics.newTextBatch(font, self.text)
end

function Button:destroy()
	View.destroy(self)
	self.text_batch:release()
end

function Button:onHover()
	self.hovered = true
end

function Button:onHoverLost()
	self.hovered = false
	self.pressed = false
end

function Button:onMouseDown()
	self.pressed = true
	return true
end

function Button:onMouseUp()
	if self.pressed then
		self.pressed = false
		if self.hovered and self.on_click then
			self.on_click()
		end
	end
end

function Button:draw()
	local w, h = self:getCalculatedWidth(), self:getCalculatedHeight()

	if self.active then
		love.graphics.setColor(Colors.accent)
	elseif self.pressed then
		love.graphics.setColor(Colors.accent[1] * 0.8, Colors.accent[2] * 0.8, Colors.accent[3] * 0.8, Colors.accent[4] or 1)
	elseif self.hovered then
		love.graphics.setColor(math.min(1, Colors.accent[1] + 0.2), math.min(1, Colors.accent[2] + 0.2), math.min(1, Colors.accent[3] + 0.2), Colors.accent[4] or 1)
	else
		love.graphics.setColor(Colors.button or {0.2, 0.2, 0.25, 1})
	end

	love.graphics.rectangle("fill", 0, 0, w, h, h / 2, h / 2)
	
	if self.active then
		love.graphics.setColor(0, 0, 0, 1)
	else
		love.graphics.setColor(Colors.text)
	end

	local tb = self.text_batch
	local tw, th = tb:getDimensions()
	love.graphics.draw(tb, w / 2 - tw / 2, h / 2 - th / 2)
end

Button.Setters = setmetatable({
	active = true,
}, {__index = View.Setters})

return Button
