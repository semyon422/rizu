local class = require("class")
local bass = require("bass")

---@class rizu.AudioModel
---@operator call: rizu.AudioModel
local AudioModel = class()

---@param device table
function AudioModel:load(device)
	if device.period == 0 then
		device.period = bass.default_dev_period
	end
	if device.buffer == 0 then
		device.buffer = bass.default_dev_buffer
	end
	bass.setDevicePeriod(device.period)
	bass.setDeviceBuffer(device.buffer)
	bass.init()
end

return AudioModel
