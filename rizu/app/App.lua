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
	self.discordModel = DiscordModel(persistence.configModel)
	self.screenshotModel = ScreenshotModel()
	self.windowModel = WindowModel()

	self.persistence = persistence
end

function App:load()
	self.discordModel:load()

	local configModel = self.persistence.configModel
	self.audioModel:load(configModel.configs.settings.audio.device)
	self.windowModel:load(configModel.configs.settings.graphics)
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
