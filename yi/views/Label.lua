local View = require("yi.views.View")
local LayoutEnums = require("ui.layout.Enums")

---@class yi.Label : yi.View
---@overload fun(font: love.Font, text: string): yi.Label
local Label = View + {}

---@param font love.Font
---@param text string
function Label:new(font, text)
	View.new(self)
	self.text_batch = love.graphics.newTextBatch(font)
	self.text = text
	self.align = "left"
	self.text_changed = false
	self.prev_w = 0
	self.prev_h = 0
end

function Label:draw()
	love.graphics.draw(self.text_batch)
end

---@param v string?
function Label:setText(v)
	if self.text == v then
		return
	end
	self.text = v or ""
	self.text_changed = true
	self.layout_box:markDirty(LayoutEnums.Axis.Both)
end

---@param v "left" | "center" | "right" | "justify"
function Label:setAlign(v)
	if self.align == v then
		return
	end
	self.align = v
	self.text_changed = true
end

function Label:updateTransforms()
	View.updateTransforms(self)

	local w, h = self:getCalculatedWidth(), self:getCalculatedHeight()

	if self.text_changed or w ~= self.prev_w or h ~= self.prev_h then
		self.text_changed = false
		self.prev_w = w
		self.prev_h = h
		self.text_batch:setf(self.text, math.max(0, w), self.align)
	end
end

---@param axis_idx ui.Axis
---@param constraint number?
function Label:getIntrinsicSize(axis_idx, constraint)
	local font = self.text_batch:getFont()
	local text = self.text

	if axis_idx == LayoutEnums.Axis.X then
		return font:getWidth(text)
	else
		local width = constraint or font:getWidth(text)
		local _, lines = font:getWrap(text, width)
		return font:getHeight() * (font:getLineHeight() * (#lines - 1) + 1)
	end
end

Label.Setters = setmetatable({
	align = Label.setAlign,
}, {__index = View.Setters})

return Label
