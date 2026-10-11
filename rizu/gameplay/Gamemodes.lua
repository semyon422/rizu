---Static on purpose: there is no way to register a gamemode at runtime yet.
---@type {[sea.Gamemode]: rizu.gameplay.Gamemode}
local Gamemodes = {
	mania = require("rizu.gameplay.mania.Gamemode"),
	osu = require("rizu.gameplay.aim.Gamemode"),
	taiko = require("rizu.gameplay.taiko.Gamemode"),
	catch = require("rizu.gameplay.catch.Gamemode"),
	sdvx = require("rizu.gameplay.sdvx.Gamemode"),
}

return Gamemodes
