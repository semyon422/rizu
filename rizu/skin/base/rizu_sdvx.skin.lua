local SdvxRenderer = require("rizu.skin.base.SdvxRenderer")

---@param context rizu.skin.SkinLoadContext
---@return rizu.skin.base.SdvxRenderer
local function load_skin(context)
	return SdvxRenderer(context.game)
end

---@class rizu.skin.base.rizu_sdvx.Skin
---@field metadata rizu.skin.SkinMetadata
---@field load fun(context: rizu.skin.SkinLoadContext): rizu.skin.base.SdvxRenderer
return {
	metadata = {
		name = "Rizu SDVX Base",
		author = "Rizu",
		version = "0.1.0",
		gamemode = "sdvx",
		input_modes = {"4bt2fx2laserleft2laserright"},
	},
	load = load_skin,
}
