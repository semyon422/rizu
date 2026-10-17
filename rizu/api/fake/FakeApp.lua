local class = require("class")

---`rizu.api.App` with one user interface and a made-up audio device.
---@class rizu.api.fake.FakeApp
---@operator call: rizu.api.fake.FakeApp
local FakeApp = class()

function FakeApp:getUserInterfaces() return {{name = "rizu", display_name = "Rizu"}} end
function FakeApp:setUserInterface(name) end
function FakeApp:getUserInterfaceDisplayName(name) return name == "rizu" and "Rizu" or nil end
function FakeApp:requestReload() end

function FakeApp:getAudioStatus()
	return {
		latency = 10, min_buffer = 5, period = 5, buffer = 10,
		device_id = 1, device_name = "Fake device", device_driver = "",
	}
end

function FakeApp:takeScreenshot(open) end

return FakeApp
