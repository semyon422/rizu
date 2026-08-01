local Config = require("rizu.config.Config")

---@class rizu.config.Settings
local Settings = {
	user_interface = "graphics.appearance.user_interface",
	show_fps = "misc.application.show_fps",
}

---@param filesystem fs.IFilesystem
---@return rizu.config.Config
function Settings.createConfig(filesystem)
	local config = Config(filesystem, "userdata/settings.json")
	config:setDefaultString(Settings.user_interface, "new")
	config:setDefaultBoolean(Settings.show_fps, false)
	return config
end

return Settings
