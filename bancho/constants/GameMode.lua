local bit = require("bit")
local class = require("class")

---@type {[integer]: bancho.GameMode}
local _byValue = {}

---@class bancho.GameMode
---@field value integer
---@field name string
local GameMode = class()

--- Internal constructor for a GameMode instance.
---@param value integer
---@param name string
---@return bancho.GameMode
local function _gm(value, name)
	return setmetatable({value = value, name = name}, GameMode)
end

GameMode.VANILLA_OSU   = _gm(0,  "VANILLA_OSU")
GameMode.VANILLA_TAIKO = _gm(1,  "VANILLA_TAIKO")
GameMode.VANILLA_CATCH = _gm(2,  "VANILLA_CATCH")
GameMode.VANILLA_MANIA = _gm(3,  "VANILLA_MANIA")
GameMode.RELAX_OSU     = _gm(4,  "RELAX_OSU")
GameMode.RELAX_TAIKO   = _gm(5,  "RELAX_TAIKO")
GameMode.RELAX_CATCH   = _gm(6,  "RELAX_CATCH")
GameMode.RELAX_MANIA   = _gm(7,  "RELAX_MANIA")
GameMode.AUTOPILOT_OSU     = _gm(8,  "AUTOPILOT_OSU")
GameMode.AUTOPILOT_TAIKO   = _gm(9,  "AUTOPILOT_TAIKO")
GameMode.AUTOPILOT_CATCH   = _gm(10, "AUTOPILOT_CATCH")
GameMode.AUTOPILOT_MANIA   = _gm(11, "AUTOPILOT_MANIA")

-- Build lookup table
local _all = {
	GameMode.VANILLA_OSU, GameMode.VANILLA_TAIKO, GameMode.VANILLA_CATCH, GameMode.VANILLA_MANIA,
	GameMode.RELAX_OSU, GameMode.RELAX_TAIKO, GameMode.RELAX_CATCH, GameMode.RELAX_MANIA,
	GameMode.AUTOPILOT_OSU, GameMode.AUTOPILOT_TAIKO, GameMode.AUTOPILOT_CATCH, GameMode.AUTOPILOT_MANIA,
}
for _, gm in ipairs(_all) do
	_byValue[gm.value] = gm
end

function GameMode.fromValue(value)
	local gm = _byValue[value]
	if not gm then
		error(("invalid game mode value: %d"):format(value), 2)
	end
	return gm
end

--- Return the vanilla mode (0-3) stripping relax/autopilot bits.
function GameMode:asVanilla()
	return self.value % 4
end

--- Construct a GameMode from a base mode value and mods bitmask.
---@param mode_vn integer vanilla mode (0-3)
---@param mods integer mods bitmask (see Mods)
function GameMode.fromParams(mode_vn, mods)
	local M = require("bancho.constants.Mods")
	if bit.band(mods, M.AUTOPILOT) ~= 0 then
		return GameMode.fromValue(mode_vn + 8)
	elseif bit.band(mods, M.RELAX) ~= 0 then
		return GameMode.fromValue(mode_vn + 4)
	end
	return GameMode.fromValue(mode_vn)
end

--- Check if this mode is a relax or autopilot variant.
function GameMode:isAuxiliary()
	return self.value >= 4
end

return GameMode
