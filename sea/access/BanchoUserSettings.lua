local class = require("class")
local valid = require("valid")
local types = require("sea.shared.types")

---@class sea.BanchoUserSettings
---@operator call: sea.BanchoUserSettings
---@field user_id integer
---@field utc_offset integer
---@field pm_private boolean
---@field stealth boolean
---@field away_msg string
---@field pres_filter integer
local BanchoUserSettings = class()

function BanchoUserSettings:new()
	self.utc_offset = 0
	self.pm_private = false
	self.stealth = false
	self.away_msg = ""
	self.pres_filter = 0
end

BanchoUserSettings.struct = {
	user_id = types.integer,
	utc_offset = types.integer,
	pm_private = types.boolean,
	stealth = types.boolean,
	away_msg = types.string,
	pres_filter = types.integer,
}

local validate_bancho_user_settings = valid.struct(BanchoUserSettings.struct)

---@return true?
---@return string|valid.Errors?
function BanchoUserSettings:validate()
	return validate_bancho_user_settings(self)
end

return BanchoUserSettings
