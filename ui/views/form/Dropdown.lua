local DropdownItems = require("ui.views.form.DropdownItems")
local Form = require("ui.views.form.Form")
local FormControl = require("ui.views.form.FormControl")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")

---@class ui.views.form.DropdownParams
---@field label string
---@field options any[]
---@field value any
---@field width? number
---@field row_height? number
---@field format? ui.views.form.DropdownFormat
---@field on_change? fun(value: any)

---@class ui.views.form.Dropdown : ui.views.form.FormControl
---@operator call: ui.views.form.Dropdown
---@field options any[]
---@field value any
---@field label_text string
---@field format ui.views.form.DropdownFormat
---@field on_change fun(value: any)?
---@field row_height number
---@field font love.Font
---@field cap_left gui.Sprite
---@field cap_middle gui.Sprite
---@field cap_right gui.Sprite
---@field chevron gui.Sprite
---@field items ui.views.form.DropdownItems?
---@field opened boolean
local Dropdown = FormControl + {}

local HEIGHT = 65
local BODY_Y = 25
local BODY_HEIGHT = 40

---@param value any
---@return string
local function defaultFormat(value)
	return tostring(value)
end

---@param params ui.views.form.DropdownParams
function Dropdown:new(params)
	FormControl.new(self)
	assert(#params.options > 0, "dropdown requires at least one option")
	self.options = params.options
	self.value = params.value
	self.label_text = params.label
	self.format = params.format or defaultFormat
	self.on_change = params.on_change
	self.row_height = params.row_height or BODY_HEIGHT
	self.font = Resources.getFont("medium", 16)
	self.cap_left = Resources.sprites.form_element_cap_left
	self.cap_middle = Resources.sprites.form_element_cap_middle
	self.cap_right = Resources.sprites.form_element_cap_right
	self.chevron = Resources.sprites.icon_chevron
	self.items = nil
	self.opened = false
	self.handles_mouse_input = true
	self:setSize(params.width or 300, HEIGHT)
	self:validateValue(self.value)
end

---@return ui.views.form.Form form
function Dropdown:getForm()
	local parent = self.parent
	while parent and not (Form * parent) do
		parent = parent.parent
	end
	parent = assert(parent, "Dropdown requires a Form ancestor")
	---@cast parent ui.views.form.Form
	return parent
end

---@param value any
function Dropdown:validateValue(value)
	for _, option in ipairs(self.options) do
		if option == value then
			return
		end
	end
	error("dropdown value must be one of its options")
end

---@param value any
---@param notify boolean?
function Dropdown:setValue(value, notify)
	self:validateValue(value)
	if self.value == value then
		return
	end
	self.value = value
	if self.items then
		self.items:setValue(value)
	end
	if notify and self.on_change then
		self.on_change(value)
	end
end

---@return boolean opened
function Dropdown:open()
	if self.opened then
		return false
	end
	local form = self:getForm()
	form:activateDropdown(self)

	local items = DropdownItems(
		self,
		self.options,
		self.format,
		self.width,
		self.row_height,
		function(value)
			self:setValue(value, true)
			self:close()
		end
	)
	items:setValue(self.value)
	local sx, sy = self.world_transform:transformPoint(0, 0)
	local x, y = form.world_transform:inverseTransformPoint(sx, sy)
	local items_height = items.offset_max[2] - items.offset_min[2]
	items:anchorFixed(x, y, self.width, items_height)
	form:addOverlay(items)

	self.items = items
	self.opened = true
	items:open()
	self:onOpened()
	return true
end

---@return boolean closed
function Dropdown:close()
	if not self.opened then
		return false
	end
	local form = self:getForm()
	local items = self.items
	self.items = nil
	self.opened = false
	form:deactivateDropdown(self)
	if items then
		items:close()
	end
	self:onClosed()
	return true
end

---Animation hook for the dropdown trigger.
function Dropdown:onOpened() end

---Animation hook for the dropdown trigger.
function Dropdown:onClosed() end

---@param e gui.MouseClickEvent
---@return boolean? handled
function Dropdown:onMouseClick(e)
	if e.button ~= 1 then
		return
	end
	if not self:close() then
		self:open()
	end
	return true
end

function Dropdown:draw()
	if self.opened then
		return
	end

	Painter.snapToPixel()
	local left_width = self.cap_left:getWidth()
	local right_width = self.cap_right:getWidth()
	local middle_width = self.width - left_width - right_width
	Painter.setColorTable(Colors.background)
	self.cap_left:draw(0, BODY_Y)
	self.cap_middle:draw(left_width, BODY_Y, 0, middle_width / self.cap_middle:getWidth(), 1)
	self.cap_right:draw(self.width - right_width, BODY_Y)

	Painter.setColorTable(Colors.text)
	love.graphics.setFont(self.font)
	love.graphics.print(self.label_text, 0, 0)
	love.graphics.print(self.format(self.value), 9, BODY_Y + (BODY_HEIGHT - self.font:getHeight()) / 2)
	self.chevron:draw(
		self.width - self.chevron:getWidth() - 8,
		BODY_Y + BODY_HEIGHT - self.chevron:getHeight() - 8
	)
end

return Dropdown
