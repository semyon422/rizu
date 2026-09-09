local VirtualInputEvent = require("rizu.input.VirtualInputEvent")
local Input = {}
local keys = {left = 1, right = 2, lshift = 3, a = 4, d = 5, rshift = 6}

---@param event {name: string, [integer]: any}
---@return rizu.VirtualInputEvent?
function Input.transform(event)
	if event.name ~= "keypressed" and event.name ~= "keyreleased" then return end
	local id = keys[event[1]]
	if id then return VirtualInputEvent(id, event.name == "keypressed", 1) end
end

return Input
