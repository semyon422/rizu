local class = require("class")

local Library = require("rizu.library.Library")
local ConfigModel = require("sphere.persistence.ConfigModel")
local FileFinder = require("sphere.persistence.FileFinder")
local DifficultyModel = require("chart.difficulty.DifficultyModel")
local LoveTimer = require("time.LoveTimer")
local ConfigManager = require("rizu.config.ConfigManager")
local Settings = require("rizu.config.schemas.Settings")

local dirs = require("sphere.persistence.dirs")

---@class sphere.Persistence
---@operator call: sphere.Persistence
local Persistence = class()

function Persistence:new()
	self.difficultyModel = DifficultyModel()
	local LoveFilesystem = require("fs.LoveFilesystem")
	self.library = Library(
		LoveFilesystem(),
		love.filesystem.getWorkingDirectory(),
		LoveTimer()
	)
	self.configModel = ConfigModel()
	self.fileFinder = FileFinder()
	self.configManager = ConfigManager(LoveFilesystem())
	self.configManager:register("settings", Settings, "userdata/settings.json")
end

function Persistence:load()
	dirs.create()

	self.configManager:loadById("settings")

	local configModel = self.configModel
	configModel:open("ai")
	configModel:open("needle")
	configModel:open("settings", true)
	configModel:open("select", true)
	configModel:open("play", true)
	configModel:open("input", true)
	configModel:open("online", true)
	configModel:open("urls")
	configModel:open("judgements")
	configModel:open("filters")
	configModel:open("files")
	configModel:read()

	self.library:load()
end

---@param name string
---@param default_path string
---@param mode boolean?
function Persistence:openAndReadThemeConfig(name, default_path, mode)
	local config_model = self.configModel
	config_model:open(name, true)
	config_model:read(name, default_path)
end

function Persistence:unload()
	self.configModel:write()
	self.configManager:saveAll()
end

return Persistence
