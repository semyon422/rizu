local class = require("class")

local DiscordModel = require("rizu.app.DiscordModel")
local WindowModel = require("rizu.app.WindowModel")
local ScreenshotModel = require("rizu.app.ScreenshotModel")
local AudioModel = require("rizu.app.AudioModel")

---@class rizu.App
---@operator call: rizu.App
local App = class()

---@param persistence sphere.Persistence
function App:new(persistence)
	self.audioModel = AudioModel()
	self.discordModel = DiscordModel(persistence.settings)
	self.screenshotModel = ScreenshotModel()
	self.windowModel = WindowModel(persistence.settings)

	self.persistence = persistence
end

function App:load()
	self.discordModel:load()

	local Settings = require("rizu.config.Settings")
	local keys = Settings.keys.audio
	local settings = self.persistence.settings
	local backend = settings:getChoice(keys.backend) --[[@as rizu.AudioBackend]]
	local device_id, device_warning = self.audioModel:findDeviceId(backend)
	if device_warning then
		print("AudioModel: " .. device_warning)
	end
	local device = AudioModel.getDeviceConfig(
		settings:getChoice(keys.device_preset),
		settings:getNumber(keys.device_period),
		settings:getNumber(keys.device_buffer)
	)
	self.audioModel:load(device, device_id, backend)
	self.windowModel:load()
end

function App:unload()
	self.discordModel:unload()
end

function App:update()
	self.discordModel:update()
	self.windowModel:update()
end

---@param event table
function App:receive(event)
	self.windowModel:receive(event)
end

return App
