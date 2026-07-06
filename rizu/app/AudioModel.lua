local class = require("class")
local audio = require("audio")

---@class rizu.AudioModel
---@operator call: rizu.AudioModel
local AudioModel = class()

---@param device table
function AudioModel:load(device)
	if device.period == 0 then
		device.period = audio.default_dev_period
	end
	if device.buffer == 0 then
		device.buffer = audio.default_dev_buffer
	end
	audio.setDevicePeriod(device.period)
	audio.setDeviceBuffer(device.buffer)
	audio.init()
end

return AudioModel
