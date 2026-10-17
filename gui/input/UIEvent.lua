local class = require("class")

---@class gui.UIEvent
---@operator call: gui.UIEvent
---@field target gui.View?
---@field current_target gui.View?
---@field control_pressed boolean
---@field shift_pressed boolean
---@field alt_pressed boolean
---@field super_pressed boolean
local UIEvent = class()

---@param modifiers gui.ModifierKeys
function UIEvent:new(modifiers)
	self.stop = false
	self.control_pressed = modifiers.control
	self.shift_pressed = modifiers.shift
	self.alt_pressed = modifiers.alt
	self.super_pressed = modifiers.super
end

function UIEvent:stopPropagation()
	self.stop = true
end

---@return gui.View?
function UIEvent:getDispatchTarget()
	return self.current_target or self.target
end

---@return boolean?
function UIEvent:trigger() end

return UIEvent
