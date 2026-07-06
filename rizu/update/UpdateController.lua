local class = require("class")
local Updater = require("rizu.update.Updater")
local UpdaterIO = require("rizu.update.UpdaterIO")
local ConfigModel = require("sphere.persistence.ConfigModel")
local WindowModel = require("rizu.app.WindowModel")
local thread = require("thread")
local delay = require("delay")

---@class rizu.UpdateController
---@operator call: rizu.UpdateController
local UpdateController = class()

function UpdateController:new()
	self.updater = Updater(UpdaterIO())
	self.configModel = ConfigModel()
	self.windowModel = WindowModel()
end

---@return boolean?
function UpdateController:updateAsync()
	local updater = self.updater
	local configModel = self.configModel

	configModel:open("settings")
	configModel:open("urls")
	configModel:open("files", true)
	configModel:read()

	local configs = configModel.configs

	if
		not configs.settings.miscellaneous.autoUpdate or
		configs.urls.update == "" or
		love.filesystem.getInfo(".git")
	then
		return
	end

	self.windowModel:load(configs.settings.graphics)

	function love.update(dt)
		thread.update()
		delay.update()
		self.windowModel:updateWindowState()
	end

	function love.draw()
		love.graphics.printf(updater.status, 0, 0, love.graphics.getWidth())
	end

	local updated, new_files = updater:updateFilesAsync(
		configs.urls.update,
		configs.files
	)
	if not updated then
		return
	end

	configs.files = new_files
	configModel:write()

	return true
end

return UpdateController
