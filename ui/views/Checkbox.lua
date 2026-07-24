local Painter = require("gui.Painter")
local View = require("gui.View")
local Resources = require("ui.Resources")

---@class ui.views.Checkbox : gui.View
---@operator call: ui.views.Checkbox
---@field checked boolean
---@field on_change fun(checked: boolean)?
---@field font love.Font
---@field label_text string
local Checkbox = View + {}

---@param params {text: string, on_change: fun(checked: boolean)?, checked: boolean?}
function Checkbox:new(params)
	View.new(self)
	self.checked = params.checked or false
	self.on_change = params.on_change

	local font = Resources.getFont("regular", 24)
	self.font = font
	self.label_text = params.text or ""

	local box_size = font:getHeight()
	local padding = 8

	self.width = box_size + padding + font:getWidth(self.label_text)
	self.height = box_size
	self.offset_max = {self.width, self.height}
	self.handles_mouse_input = true
end

---@param e gui.MouseClickEvent
function Checkbox:onMouseClick(e)
	if e.button ~= 1 then
		return
	end
	self.checked = not self.checked
	if self.on_change then
		self.on_change(self.checked)
	end
	return true
end

local lg = love.graphics

function Checkbox:draw()
	local box_size = self.font:getHeight()
	Painter.setColorRgb(1, 1, 1)
	lg.rectangle("fill", 0, 0, box_size, box_size)
	Painter.setColorRgb(0, 0, 0)
	lg.rectangle("line", 0, 0, box_size, box_size)
	if self.checked then
		Painter.setColorRgb(0, 0, 0)
		lg.rectangle("fill", 5, 5, box_size - 10, box_size - 10)
	end
	Painter.setColorRgb(1, 1, 1)
	lg.setFont(self.font)
	lg.print(self.label_text, box_size + 8, 0)
end

return Checkbox
