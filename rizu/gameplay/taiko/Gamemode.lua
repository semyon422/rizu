local Gamemode = require("rizu.gameplay.Gamemode")
local Preparation = require("rizu.gameplay.taiko.Preparation")

---@class rizu.gameplay.taiko.Gamemode : rizu.gameplay.Gamemode
local TaikoGamemode = Gamemode + {}

TaikoGamemode.name = "taiko"
TaikoGamemode.prepare = Preparation.compute

---@return rizu.taiko.Input
function TaikoGamemode.createInput()
	return require("rizu.gameplay.taiko.Input")()
end

---@return rizu.gameplay.taiko.Engine
function TaikoGamemode.createEngine()
	return require("rizu.gameplay.taiko.Engine")()
end

return TaikoGamemode
