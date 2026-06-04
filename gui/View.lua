local IInputHandler = require("gui.input.IInputHandler")

---@alias gui.ViewPoint [number, number]
---@alias gui.Color [number, number, number, number]

---@class gui.View : gui.IInputHandler
---@operator call: gui.View
---@field x number
---@field y number
---@field width number
---@field height number
---@field pivot gui.ViewPoint
---@field rotation number
---@field scale_x number
---@field scale_y number
---@field transform love.Transform
---@field box gui.Box?
---@field visible boolean
---@field width_percent number? -- 0..1 ratio of parent box width
---@field height_percent number? -- 0..1 ratio of parent box height
---@field is_focusable boolean
---@field focused boolean
---@field mouse_over boolean
---@field pressed boolean
local View = IInputHandler + {}

View._is_view = true

function View:new()
	self.x = 0
	self.y = 0
	self.width = 0
	self.height = 0
	self.pivot = {0, 0}
	self.transform = love.math.newTransform()
	self.box = nil
	self.visible = true
	self.rotation = 0
	self.scale_x = 1
	self.scale_y = 1

	self.is_focusable = false
	self.focused = false
	self.mouse_over = false
	self.pressed = false
	self.handles_mouse_input = false
	self.handles_keyboard_input = false
	self._constructed = true
end

function View:load() end

---@param e gui.FocusEvent
function View:onFocus(e) end

---@param e gui.FocusLostEvent
function View:onFocusLost(e) end

local temp_tf = love.math.newTransform()

function View:updateTransform()
	local box = self.box
	assert(box, "gui.View:updateTransform() requires self.box")
	local pivot = self.pivot
	local box_width = box.width
	local box_height = box.height
	local ax, ay = box_width * pivot[1], box_height * pivot[2]
	local ox, oy = self.width * pivot[1], self.height * pivot[2]
	local x, y = self.x + self.box.x + ax, self.y + self.box.y + ay
	local sx = self.scale_x
	local sy = self.scale_y
	local r = self.rotation
	temp_tf:setTransformation(x, y, r, sx, sy, ox, oy)
	self.transform:reset()
	self.transform:apply(box.transform)
	self.transform:apply(temp_tf)
end

---@param screen_x number
---@param screen_y number
---@return boolean
function View:isMouseOver(screen_x, screen_y)
	if not self.visible or not self.handles_mouse_input then
		return false
	end
	local imx, imy = self.transform:inverseTransformPoint(screen_x, screen_y)
	return imx >= 0 and imx <= self.width and imy >= 0 and imy <= self.height
end

---@param inputs gui.Inputs
function View:acceptInputs(inputs)
	inputs:processView(self)
end

---@param dt number
function View:update(dt) end

function View:draw() end

---@return number
function View:getWidth()
	return self.width
end

---@return number
function View:getHeight()
	return self.height
end

---@param x number
---@param y number
---@return self
function View:setPosition(x, y)
	self.x = x
	self.y = y
	return self
end

---@param width number
---@param height number
---@return self
function View:setSize(width, height)
	self.width = width
	self.height = height
	return self
end

---@param width number
---@return self
function View:setWidth(width)
	self.width = width
	return self
end

---@param height number
---@return self
function View:setHeight(height)
	self.height = height
	return self
end

---@param x number
---@param y number
---@param width number
---@param height number
---@return self
function View:setBounds(x, y, width, height)
	self.x = x
	self.y = y
	self.width = width
	self.height = height
	return self
end

---@param x number
---@param y number
---@return self
function View:setPivot(x, y)
	self.pivot = {x, y}
	return self
end

---@param angle number
---@return self
function View:setRotation(angle)
	self.rotation = angle
	return self
end

---@param x number
---@param y? number
---@return self
function View:setScale(x, y)
	self.scale_x = x
	self.scale_y = y or x
	return self
end

---@return number 
---@return number
function View:getDimensions()
	return self.width, self.height
end

return View
