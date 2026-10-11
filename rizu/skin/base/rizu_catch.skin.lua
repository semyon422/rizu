local OsuFruitsRenderer = require("rizu.skin.osu.OsuFruitsRenderer")

---The renderer draws with the osu! skin selected in settings.
---@param context rizu.skin.SkinLoadContext
---@return rizu.skin.osu.OsuFruitsRenderer
local function load_skin(context)
	return OsuFruitsRenderer(context.game)
end

---@class rizu.skin.base.rizu_catch.Skin
---@field metadata rizu.skin.SkinMetadata
---@field load fun(context: rizu.skin.SkinLoadContext): rizu.skin.osu.OsuFruitsRenderer
return {
	metadata = {
		name = "Rizu Catch Base",
		author = "Rizu",
		version = "0.1.0",
		gamemode = "catch",
		input_modes = {"any"},
	},
	load = load_skin,
}
