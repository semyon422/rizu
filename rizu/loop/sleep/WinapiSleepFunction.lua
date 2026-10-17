local ISleepFunction = require("rizu.loop.sleep.ISleepFunction")

---@class rizu.WinapiSleepFunction: rizu.ISleepFunction
---@operator call: rizu.WinapiSleepFunction
local WinapiSleepFunction = ISleepFunction + {}

function WinapiSleepFunction:new()
	local winapi = require("winapi")
	self.winapi_sleep = winapi.sleep
	-- Initialize the waitable timer
	self.winapi_sleep(0)
end

function WinapiSleepFunction:sleep(s)
	self.winapi_sleep(s)
end

function WinapiSleepFunction:isAvailable(os_name)
	return os_name == "Windows"
end

return WinapiSleepFunction
