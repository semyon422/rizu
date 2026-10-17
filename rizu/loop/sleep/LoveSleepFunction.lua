local ISleepFunction = require("rizu.loop.sleep.ISleepFunction")

---@class rizu.LoveSleepFunction: rizu.ISleepFunction
---@operator call: rizu.LoveSleepFunction
local LoveSleepFunction = ISleepFunction + {}

function LoveSleepFunction:sleep(s)
	love.timer.sleep(s)
end

function LoveSleepFunction:isAvailable(os_name)
	return true
end

return LoveSleepFunction
