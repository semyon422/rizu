local View = require("gui.View")

---@class ui.views.PopupOwner
---@field close fun(self: ui.views.PopupOwner): boolean

---@class ui.views.PopupContainer : gui.View
---@operator call: ui.views.PopupContainer
---@field owner ui.views.PopupOwner?
---@field popup gui.View?
local PopupContainer = View + {}

function PopupContainer:new()
	View.new(self)
	self:anchorFill(0, 0, 0, 0)
	self.owner = nil
	self.popup = nil
	self.handles_mouse_input = false
end

---Positions a popup at a source view while preserving the source's visual scale
---and rotation relative to this container.
---@param popup gui.View
---@param source gui.View
function PopupContainer:placeAtSource(popup, source)
	local source_transform = source.world_transform
	local container_transform = self.world_transform
	local sx, sy = source_transform:transformPoint(0, 0)
	local sxx, sxy = source_transform:transformPoint(1, 0)
	local syx, syy = source_transform:transformPoint(0, 1)
	local x, y = container_transform:inverseTransformPoint(sx, sy)
	local xx, xy = container_transform:inverseTransformPoint(sxx, sxy)
	local yx, yy = container_transform:inverseTransformPoint(syx, syy)
	local axis_x_x, axis_x_y = xx - x, xy - y
	local axis_y_x, axis_y_y = yx - x, yy - y
	local scale_x = math.sqrt(axis_x_x ^ 2 + axis_x_y ^ 2)
	local scale_y = math.sqrt(axis_y_x ^ 2 + axis_y_y ^ 2)
	if axis_x_x * axis_y_y - axis_x_y * axis_y_x < 0 then
		scale_y = -scale_y
	end
	popup:setPosition(x, y)
	popup:setScale(scale_x, scale_y)
	popup:setRotation(math.atan2(axis_x_y, axis_x_x))
end

---@param owner ui.views.PopupOwner
---@param popup gui.View
---@param source gui.View?
function PopupContainer:open(owner, popup, source)
	local active_owner = self.owner
	if active_owner and active_owner ~= owner then
		active_owner:close()
	end
	assert(not self.popup, "popup container already has a popup")
	if source then
		self:placeAtSource(popup, source)
	end
	self.owner = owner
	self.popup = popup
	self.handles_mouse_input = true
	self:add(popup)
end

---@param child gui.View
function PopupContainer:remove(child)
	View.remove(self, child)
	if child == self.popup then
		self.owner = nil
		self.popup = nil
		self.handles_mouse_input = false
	end
end

---@return boolean handled
function PopupContainer:onMouseDown()
	local owner = self.owner
	if owner then
		owner:close()
	end
	return true
end

---@return boolean handled
function PopupContainer:onScroll()
	local owner = self.owner
	if owner then
		owner:close()
	end
	return true
end

return PopupContainer
