local class = require("class")

local DiscordModel = require("rizu.app.DiscordModel")
local WindowModel = require("rizu.app.WindowModel")
local ScreenshotModel = require("rizu.app.ScreenshotModel")
local AudioModel = require("rizu.app.AudioModel")

---@class rizu.App
---@operator call: rizu.App
---@field saved_volume integer? Stream volume to restore when focus returns
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

function App:updateMute()
	local Settings = require("rizu.config.Settings")
	local bass = require("bass")
	local bass_config = require("bass.config")
	local option = bass_config.BASS_CONFIG_GVOL_STREAM
	local mute = self.persistence.settings:getBoolean(Settings.keys.misc.mute_on_unfocus) and not love.window.hasFocus()
	if mute == (self.saved_volume ~= nil) then
		return
	end
	if mute then
		self.saved_volume = bass.BASS_GetConfig(option)
		bass.BASS_SetConfig(option, 0)
	else
		bass.BASS_SetConfig(option, self.saved_volume)
		self.saved_volume = nil
	end
end

function App:update()
	self:updateMute()
	self.discordModel:update()
	self.windowModel:update()
end

---@param event table
function App:receive(event)
	self.windowModel:receive(event)
end

return App
