local OsuAimRenderer = require("rizu.skin.osu.OsuAimRenderer")

---The renderer draws with the osu! skin selected in settings.
---@param context rizu.skin.SkinLoadContext
---@return rizu.skin.osu.OsuAimRenderer
local function load_skin(context)
	return OsuAimRenderer(context.game)
end

---@class rizu.skin.base.rizu_osu.Skin
---@field metadata rizu.skin.SkinMetadata
---@field load fun(context: rizu.skin.SkinLoadContext): rizu.skin.osu.OsuAimRenderer
return {
	metadata = {
		name = "Rizu Osu Base",
		author = "Rizu",
		version = "0.1.0",
		gamemode = "osu",
		input_modes = {"any"},
	},
	load = load_skin,
}
