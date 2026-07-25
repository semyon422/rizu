local DropdownHost = require("ui.views.DropdownHost")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local View = require("gui.View")

---@class ui.views.Dropdown.Params
---@field options any[]
---@field value any
---@field width? number
---@field row_height? number
---@field format? ui.views.DropdownFormat
---@field on_change? fun(value: any)

---@class ui.views.Dropdown : gui.View
---@operator call: ui.views.Dropdown
---@field options any[]
---@field value any
---@field format ui.views.DropdownFormat
---@field on_change fun(value: any)?
---@field row_height number
---@field font love.Font
local Dropdown = View + {}

---@param value any
---@return string
local function defaultFormat(value)
	return tostring(value)
end

---@param params ui.views.Dropdown.Params
function Dropdown:new(params)
	View.new(self)
	assert(#params.options > 0, "dropdown requires at least one option")
	self.options = params.options
	self.value = params.value
	self.format = params.format or defaultFormat
	self.on_change = params.on_change
	self.row_height = params.row_height or 42
	self.font = Resources.getFont("regular", 24)
	self.handles_mouse_input = true
	self:setSize(params.width or 300, self.row_height)
end

---@return ui.views.DropdownHost host
function Dropdown:getHost()
	local parent = self.parent
	while parent and not (DropdownHost * parent) do
		parent = parent.parent
	end
	parent = assert(parent, "Dropdown requires a DropdownHost ancestor")
	---@cast parent ui.views.DropdownHost
	return parent
end

---@param value any
---@param notify boolean?
function Dropdown:setValue(value, notify)
	local found = false
	for _, option in ipairs(self.options) do
		if option == value then
			found = true
			break
		end
	end
	assert(found, "dropdown value must be one of its options")
	if self.value == value then
		return
	end
	self.value = value
	local host = self:getHost()
	if host.active_dropdown == self and host.items then
		host.items:setValue(value)
	end
	if notify and self.on_change then
		self.on_change(value)
	end
end

---@return boolean opened
function Dropdown:open()
	return self:getHost():openDropdown(self)
end

---@return boolean closed
function Dropdown:close()
	return self:getHost():closeDropdown(self)
end

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
	local lg = love.graphics
	Painter.setColorRgb(self.mouse_over and 0.25 or 0.16, self.mouse_over and 0.22 or 0.16, self.mouse_over and 0.33 or 0.20)
	lg.rectangle("fill", 0, 0, self.width, self.height)
	Painter.setColorRgb(0.55, 0.52, 0.65)
	lg.rectangle("line", 0, 0, self.width, self.height)
	Painter.setColorRgb(0.95, 0.95, 1)
	lg.setFont(self.font)
	lg.print(self.format(self.value), 10, (self.height - self.font:getHeight()) / 2)
	local x = self.width - 20
	local y = self.height / 2
	lg.polygon("fill", x - 5, y - 3, x + 5, y - 3, x, y + 4)
end

return Dropdown
