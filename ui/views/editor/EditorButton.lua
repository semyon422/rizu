local EditorRow = require("ui.views.editor.EditorRow")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")

---"field" is a filled field, "danger" turns red under the mouse, "ghost" only shows under the mouse.
---@alias ui.views.editor.EditorButton.Variant "field"|"danger"|"ghost"

---@class ui.views.editor.EditorButtonParams
---@field label string? Row label; the text then sits at the left of the field, like a value.
---@field text string
---@field width number? Fits the text when omitted.
---@field height number?
---@field variant ui.views.editor.EditorButton.Variant?
---@field on_click fun()

---@class ui.views.editor.EditorButton : ui.views.editor.EditorRow
---@operator call: ui.views.editor.EditorButton
---@field text string
---@field variant ui.views.editor.EditorButton.Variant
---@field on_click fun()
local EditorButton = EditorRow + {}

local PADDING = 12

---@param params ui.views.editor.EditorButtonParams
function EditorButton:new(params)
	local font = Resources.getFont("regular", 16)
	EditorRow.new(self, params.label, params.width or font:getWidth(params.text) + PADDING * 2)
	if params.height then self:setHeight(params.height) end
	self.text = params.text
	self.variant = params.variant or "field"
	self.on_click = params.on_click
end

---@param text string
function EditorButton:setText(text)
	self.text = text
end

---@param e gui.MouseClickEvent
---@return boolean?
function EditorButton:onMouseClick(e)
	if e.button ~= 1 then return end
	self.on_click()
	return true
end

function EditorButton:draw()
	Painter.snapToPixel()
	self:drawLabel()
	local x, width = self:getField()
	local hover = self.mouse_over and self.effective_enabled
	local color ---@type gui.Color?
	if hover then
		color = self.variant == "danger" and Colors.danger or Colors.surface_raised
	elseif self.variant ~= "ghost" then
		color = Colors.surface
	end
	if color then EditorRow.fillRect(color, x, 0, width, self.height) end
	Painter.setColorTable(self.effective_enabled and Colors.text or Colors.muted)
	if self.label_text then
		self:printText(self.text, x + EditorRow.TEXT_X, width - EditorRow.TEXT_X * 2, "left")
	else
		self:printText(self.text, x, width, "center")
	end
end

return EditorButton
