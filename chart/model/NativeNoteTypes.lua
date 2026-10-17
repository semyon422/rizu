-- Explicit native playable note types. Names are opaque, not parsed.
---@type {[string]: sea.Gamemode}
local modes = {
	["osu:circle"] = "osu",
	["osu:slider"] = "osu",
	["osu:spinner"] = "osu",
	["osu:unsupported"] = "osu",
	["catch:fruit"] = "catch",
	["catch:droplet"] = "catch",
	["catch:tiny"] = "catch",
	["catch:banana"] = "catch",
	["taiko:note"] = "taiko",
	["taiko:roll"] = "taiko",
	["taiko:spinner"] = "taiko",
	["sdvx:button"] = "sdvx",
	["sdvx:laser"] = "sdvx",
}

return modes
