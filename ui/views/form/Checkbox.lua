local FormControl = require("ui.views.form.FormControl")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")

---@class ui.views.form.CheckboxParams
---@field text string
---@field on_change fun(checked: boolean)?
---@field checked boolean?

---@class ui.views.form.Checkbox : ui.views.form.FormControl
---@operator call: ui.views.form.Checkbox
---@field checked boolean
---@field on_change fun(checked: boolean)?
---@field font love.Font
---@field label_text string
---@field body gui.Sprite
---@field mark gui.Sprite
local Checkbox = FormControl + {}

local HEIGHT = 30
local TEXT_GAP = 8

---@param params ui.views.form.CheckboxParams
function Checkbox:new(params)
	FormControl.new(self)
	self.checked = params.checked == true
	self.on_change = params.on_change
	self.font = Resources.getFont("medium", 16)
	self.label_text = params.text
	self.body = Resources.sprites.checkbox_body
	self.mark = Resources.sprites.checkbox_mark

	local body_width = self.body:getHeight()
	self:setSize(body_width + TEXT_GAP + self.font:getWidth(self.label_text), HEIGHT)
	self.handles_mouse_input = true
end

---@param checked boolean
---@param notify boolean?
function Checkbox:setChecked(checked, notify)
	if self.checked == checked then
		return
	end
	self.checked = checked
	if notify and self.on_change then
		self.on_change(checked)
	end
end

---@param e gui.MouseClickEvent
---@return boolean?
function Checkbox:onMouseClick(e)
	if e.button ~= 1 then
		return
	end
	self:setChecked(not self.checked, true)
	return true
end

function Checkbox:draw()
	Painter.snapToPixel()
	Painter.setColorTable(Colors.background)
	self.body:draw()

	if self.checked then
		local body_width, body_height = self.body:getDimensions()
		local mark_width, mark_height = self.mark:getDimensions()
		Painter.setColorTable(Colors.accent)
		self.mark:draw((body_width - mark_width) / 2, (body_height - mark_height) / 2)
	end

	Painter.setColorTable(Colors.text)
	love.graphics.setFont(self.font)
	love.graphics.print(
		self.label_text,
		self.body:getWidth() + TEXT_GAP,
		(HEIGHT - self.font:getHeight()) / 2
	)
end

return Checkbox
