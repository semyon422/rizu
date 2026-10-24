local EditorRow = require("ui.views.editor.EditorRow")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")

---@class ui.views.editor.EditorCheckboxParams
---@field label string
---@field checked boolean
---@field width number
---@field on_change fun(checked: boolean)?

---A square box at the right end of the field. A click anywhere on the row toggles it.
---@class ui.views.editor.EditorCheckbox : ui.views.editor.EditorRow
---@operator call: ui.views.editor.EditorCheckbox
---@field checked boolean
---@field on_change fun(checked: boolean)?
local EditorCheckbox = EditorRow + {}

local BOX_SIZE = 24

---@param params ui.views.editor.EditorCheckboxParams
function EditorCheckbox:new(params)
	EditorRow.new(self, params.label, params.width)
	self.checked = params.checked == true
	self.on_change = params.on_change
end

---@param e gui.MouseClickEvent
---@return boolean?
function EditorCheckbox:onMouseClick(e)
	if e.button ~= 1 then return end
	self.checked = not self.checked
	if self.on_change then self.on_change(self.checked) end
	return true
end

function EditorCheckbox:draw()
	Painter.snapToPixel()
	self:drawLabel()
	local field_x, field_width = self:getField()
	local x = field_x + field_width - BOX_SIZE
	local y = math.floor((self.height - BOX_SIZE) / 2)
	EditorRow.fillRect(self.mouse_over and Colors.surface_raised or Colors.surface, x, y, BOX_SIZE, BOX_SIZE)
	if self.checked then
		local mark = Resources.sprites.icon_check
		local mark_width, mark_height = mark:getDimensions()
		Painter.setColorTable(Colors.accent)
		mark:draw(x + (BOX_SIZE - mark_width) / 2, y + (BOX_SIZE - mark_height) / 2)
	end
end

return EditorCheckbox
