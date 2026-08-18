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
---@field active_form ui.views.form.Form?
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
	self.active_form = nil
	self.opened = false
	self.handles_mouse_input = true
	self:setSize(params.width or 300, HEIGHT)
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

---@return boolean selectable
function Dropdown:canBeSelected()
	return FormControl.canBeSelected(self) and #self.options > 0
end

---@param value any
---@param notify boolean?
function Dropdown:setValue(value, notify)
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
	if self.opened or #self.options == 0 then
		return false
	end
	local form = self:getForm()
	form:activateDropdown(self)
	self.active_form = form

	local items = DropdownItems(
		self,
		self.options,
		self.format,
		self.width,
		self.row_height,
		function(value)
			self:setValue(value, true)
			self:close()
			form:centerView(self)
		end
	)
	items:setValue(self.value)
	local screen = assert(form.screen, "Dropdown requires an attached Form")
	local popup_container = screen.popup_container
		or screen.ui and screen.ui.overlay.popup_container
	assert(popup_container, "Dropdown requires a popup container")
	local items_height = items.offset_max[2] - items.offset_min[2]
	items:setSize(self.width, items_height)
	popup_container:open(self, items, self)

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
	local form = assert(self.active_form, "open dropdown has no active form")
	local items = self.items
	self.items = nil
	self.active_form = nil
	self.opened = false
	form:deactivateDropdown(self)
	if items then
		items:close()
	end
	self:onClosed()
	return true
end

---@param e gui.KeyDownEvent
---@return boolean activated
function Dropdown:activate(e)
	if self.opened then
		local items = assert(self.items, "open dropdown has no items")
		return items:selectFocused()
	end
	return self:open()
end

---@param e gui.KeyDownEvent
---@return boolean handled
function Dropdown:onFormKeyDown(e)
	local items = self.items
	if not items then
		return false
	end
	if e.key == "down" then
		return items:moveFocus(1)
	elseif e.key == "up" then
		return items:moveFocus(-1)
	end
	return false
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
	local value_text = self.value == nil and "" or self.format(self.value)
	love.graphics.print(value_text, 9, BODY_Y + (BODY_HEIGHT - self.font:getHeight()) / 2)
	self.chevron:draw(
		self.width - self.chevron:getWidth() - 8,
		BODY_Y + BODY_HEIGHT - self.chevron:getHeight() - 8
	)
end

return Dropdown
