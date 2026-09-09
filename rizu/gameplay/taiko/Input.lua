local VirtualInputEvent = require("rizu.input.VirtualInputEvent")

local Input = {}
---@type {[string]: integer}
local ids = {f = 1, j = 2, d = 3, k = 4}

---@param event table
---@return rizu.VirtualInputEvent?
function Input.transform(event)
	if event.name ~= "keypressed" and event.name ~= "keyreleased" then return end
	local id = ids[event[1]]
	if not id then return end
	return VirtualInputEvent(id, event.name == "keypressed", 1)
end

return Input
