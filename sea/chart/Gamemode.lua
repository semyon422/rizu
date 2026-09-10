local Enum = require("rdb.Enum")

---@enum (key) sea.Gamemode
local Gamemode = {
	mania = 0,
	taiko = 1,
	osu = 2,
	catch = 3,
	sdvx = 4,
}

return Enum(Gamemode)
