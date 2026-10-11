local OsuTaikoRenderer = require("rizu.skin.osu.OsuTaikoRenderer")

---The renderer draws with the osu! skin selected in settings.
---@param context rizu.skin.SkinLoadContext
---@return rizu.skin.osu.OsuTaikoRenderer
local function load_skin(context)
	return OsuTaikoRenderer(context.game)
end

---@class rizu.skin.base.rizu_taiko.Skin
---@field metadata rizu.skin.SkinMetadata
---@field load fun(context: rizu.skin.SkinLoadContext): rizu.skin.osu.OsuTaikoRenderer
return {
	metadata = {
		name = "Rizu Taiko Base",
		author = "Rizu",
		version = "0.1.0",
		gamemode = "taiko",
		input_modes = {"any"},
	},
	load = load_skin,
}
