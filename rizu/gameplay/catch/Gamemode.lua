local Gamemode = require("rizu.gameplay.Gamemode")
local Preparation = require("rizu.gameplay.catch.Preparation")

---@class rizu.gameplay.catch.Gamemode : rizu.gameplay.Gamemode
local CatchGamemode = Gamemode + {}

CatchGamemode.name = "catch"
CatchGamemode.prepare = Preparation.compute

return CatchGamemode
