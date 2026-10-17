local class = require("class")
local VirtualInputEvent = require("rizu.input.VirtualInputEvent")

---@class rizu.aim.Input
---@operator call: rizu.aim.Input
local Input = class()

function Input:new()
	self.x, self.y = 256, 192
end

---@param x number
---@param y number
---@return rizu.VirtualInputEvent
function Input:move(x, y)
	self.x, self.y = x, y
	return VirtualInputEvent(0, nil, 1, {x, y})
end

---@param event {name: string, [integer]: any}
---@return rizu.VirtualInputEvent?
function Input:transform(event)
	local id, pressed
	if event.name == "inputchanged" and event[1] == "keyboard" then
		if event[3] == "z" then id = 1 end
		if event[3] == "x" then id = 2 end
		pressed = event[4]
	elseif event.name == "mousepressed" or event.name == "mousereleased" then
		if event[3] == 1 then id = 3 end
		if event[3] == 2 then id = 4 end
		pressed = event.name == "mousepressed"
	end
	if id then
		return VirtualInputEvent(id, pressed, 1, {self.x, self.y})
	end
end

return Input
