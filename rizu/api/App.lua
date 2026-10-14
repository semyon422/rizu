local class = require("class")

--[[
The program around the game: which user interface runs, the audio device, screenshots.

	local app = ui.api.app
	for _, interface in ipairs(app:getUserInterfaces()) do ... end
	app:setUserInterface("rizu")
	app:requestReload()
]]

---A user interface the game can run.
---@class rizu.api.UserInterfaceInfo
---@field name string Unique id, for setUserInterface().
---@field display_name string

---What the audio device is doing. Sizes are in milliseconds.
---@class rizu.api.AudioStatus
---@field latency number
---@field min_buffer number
---@field period number
---@field buffer number
---@field device_id integer
---@field device_name string
---@field device_driver string "" when the system does not say.
---@field warning string? Why the chosen device could not be used.
---@field transport string? "SDL3" when the game plays through SDL instead of BASS.
---@field queued_ms number? SDL3 only.
---@field underruns integer? SDL3 only.

---@class rizu.api.App
---@operator call: rizu.api.App
---@field private game sphere.GameController
local App = class()

---@param game sphere.GameController
function App:new(game)
	self.game = game
end

---@return rizu.api.UserInterfaceInfo[]
function App:getUserInterfaces()
	return self.game.user_interface_manager:getUserInterfaces() --[[@as rizu.api.UserInterfaceInfo[] ]]
end

---@param name string One of getUserInterfaces(). Takes effect after requestReload().
function App:setUserInterface(name) self.game.user_interface_manager:setUserInterface(name) end

---@param name string
---@return string? display_name nil for an unknown name
function App:getUserInterfaceDisplayName(name)
	return self.game.user_interface_manager:getUserInterfaceDisplayName(name)
end

---Unloads this user interface and loads the selected one, after the current frame.
function App:requestReload() self.game.user_interface_manager:requestReload() end

---@return rizu.api.AudioStatus
function App:getAudioStatus() return self.game.app.audioModel:getStatus() end

---Saves what is on the screen as a picture.
---@param open boolean Show the folder with the picture afterwards.
function App:takeScreenshot(open) self.game.app.screenshotModel:capture(open) end

return App
