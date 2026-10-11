local Gamemode = require("rizu.gameplay.Gamemode")
local Preparation = require("rizu.gameplay.sdvx.Preparation")

---@class rizu.gameplay.sdvx.Gamemode : rizu.gameplay.Gamemode
local SdvxGamemode = Gamemode + {}

SdvxGamemode.name = "sdvx"
SdvxGamemode.prepare = Preparation.compute

---@return rizu.sdvx.Input
function SdvxGamemode.createInput()
	return require("rizu.gameplay.sdvx.Input")()
end

---@return rizu.gameplay.sdvx.Engine
function SdvxGamemode.createEngine()
	return require("rizu.gameplay.sdvx.Engine")()
end

return SdvxGamemode
