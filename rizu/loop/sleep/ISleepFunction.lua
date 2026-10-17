local class = require("class")

---@class rizu.ISleepFunction
---@operator call: rizu.ISleepFunction
local ISleepFunction = class()

---@param s number
function ISleepFunction:sleep(s)
	error("not implemented")
end

---@param os_name string
---@return boolean
function ISleepFunction:isAvailable(os_name)
	return false
end

return ISleepFunction
