local Gamemode = require("rizu.gameplay.Gamemode")
local Preparation = require("rizu.gameplay.sdvx.Preparation")

---@class rizu.gameplay.sdvx.Gamemode : rizu.gameplay.Gamemode
local SdvxGamemode = Gamemode + {}

SdvxGamemode.name = "sdvx"
SdvxGamemode.prepare = Preparation.compute

return SdvxGamemode
