local Config = require("rizu.config.Config")

---@class rizu.config.Settings
local Settings = {
	user_interface = "graphics.appearance.user_interface",
}

---@param filesystem fs.IFilesystem
---@return rizu.config.Config
function Settings.createConfig(filesystem)
	local config = Config(filesystem, "userdata/settings.json")
	config:setDefaultString(Settings.user_interface, "new")
	return config
end

return Settings
