local Gamemode = require("rizu.gameplay.Gamemode")
local Preparation = require("rizu.gameplay.catch.Preparation")

---@class rizu.gameplay.catch.Gamemode : rizu.gameplay.Gamemode
local CatchGamemode = Gamemode + {}

CatchGamemode.name = "catch"
CatchGamemode.prepare = Preparation.compute

---@return rizu.catch.Input
function CatchGamemode.createInput()
	return require("rizu.gameplay.catch.Input")()
end

---@return rizu.gameplay.catch.Engine
function CatchGamemode.createEngine()
	return require("rizu.gameplay.catch.Engine")()
end

return CatchGamemode
