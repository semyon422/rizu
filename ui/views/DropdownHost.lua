local DropdownItems = require("ui.views.DropdownItems")
local FlowContainer = require("gui.layout.FlowContainer")
local View = require("gui.View")

---@class ui.views.DropdownBackdrop : gui.View
---@operator call: ui.views.DropdownBackdrop
---@field host ui.views.DropdownHost
local DropdownBackdrop = View + {}

---@param host ui.views.DropdownHost
function DropdownBackdrop:new(host)
	View.new(self)
	self.host = host
	self.handles_mouse_input = true
	self:setLayoutIgnore(true)
	self:anchorFill(0, 0, 0, 0)
end

---@param e gui.MouseDownEvent
---@return boolean? handled
function DropdownBackdrop:onMouseDown(e)
	if e.button == 1 then
		self.host:closeDropdown()
		return true
	end
end

---@param e gui.ScrollEvent
function DropdownBackdrop:onScroll(e)
	self.host:closeDropdown()
end

---@class ui.views.DropdownHost.Config : gui.layout.FlowContainer.Config

---Coordinates one inline dropdown panel above all ordinary descendants.
---@class ui.views.DropdownHost : gui.layout.FlowContainer
---@operator call: ui.views.DropdownHost
---@overload fun(config: ui.views.DropdownHost.Config?): ui.views.DropdownHost
---@field active_dropdown ui.views.Dropdown?
---@field items ui.views.DropdownItems?
---@field backdrop ui.views.DropdownBackdrop?
local DropdownHost = FlowContainer + {}

---@param config ui.views.DropdownHost.Config?
function DropdownHost:new(config)
	FlowContainer.new(self, config)
	self.handles_keyboard_input = true
	self.keyboard_input_fallback = true
	self.active_dropdown = nil
	self.items = nil
	self.backdrop = nil
end

---@param dropdown ui.views.Dropdown
---@return boolean opened
function DropdownHost:openDropdown(dropdown)
	if self.active_dropdown == dropdown then
		return false
	end
	self:closeDropdown()

	local sx, sy = dropdown.world_transform:transformPoint(0, dropdown.height)
	local x, y = self.world_transform:inverseTransformPoint(sx, sy)
	local items = DropdownItems(
		dropdown.options,
		dropdown.format,
		dropdown.width,
		dropdown.row_height,
		function(value)
			dropdown:setValue(value, true)
			self:closeDropdown(dropdown)
		end
	)
	items:setValue(dropdown.value)
	items:anchorFixed(x, y, dropdown.width, dropdown.row_height * #dropdown.options)

	local backdrop = DropdownBackdrop(self)
	self:add(backdrop)
	self:add(items)
	self.active_dropdown = dropdown
	self.backdrop = backdrop
	self.items = items
	return true
end

---@param dropdown ui.views.Dropdown?
---@return boolean closed
function DropdownHost:closeDropdown(dropdown)
	if not self.active_dropdown or dropdown and dropdown ~= self.active_dropdown then
		return false
	end
	local items = self.items
	local backdrop = self.backdrop
	self.active_dropdown = nil
	self.items = nil
	self.backdrop = nil
	if items and items.parent == self then
		self:remove(items)
	end
	if backdrop and backdrop.parent == self then
		self:remove(backdrop)
	end
	return true
end

---@param e gui.KeyDownEvent
---@return boolean? handled
function DropdownHost:onKeyDown(e)
	if e.key == "escape" then
		return self:closeDropdown()
	end
end

return DropdownHost
