local BanchoUserSettings = require("sea.access.BanchoUserSettings")

---@type rdb.ModelOptions
local bancho_user_settings = {}

bancho_user_settings.metatable = BanchoUserSettings

bancho_user_settings.types = {
	pm_private = "boolean",
	stealth = "boolean",
}

return bancho_user_settings
