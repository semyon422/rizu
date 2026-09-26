local OsuAimRenderer = require("rizu.skin.osu.OsuAimRenderer")
local test = {}

---@param t testing.T
function test.loads_selected_osu_skin_and_uses_sprite_renderers(t)
	local loaded = {}
	local skins = {
		{path = "skins/one", files = {}},
		{path = "skins/two", files = {}},
	}
	local game = {
		fs = {},
		skinRegistry = {
			getOsuSkin = function(_, path)
				for _, skin in ipairs(skins) do
					if skin.path == path then return skin end
				end
			end,
			getOsuSkins = function() return skins end,
		},
		settings = {getStringMap = function() return {["osu/1osu"] = "skins/two"} end},
		rhythm_engine = {aim_rules = {objects = {}}, visual_info = {time = 0}},
	}
	local renderer = OsuAimRenderer(game)
	local renderer_fields = renderer
	renderer_fields.slider_graphics.prepare = function() end
	renderer_fields.slider_graphics.load = function() end
	---@type {skin: {path: string}, images: table, loaded: boolean}
	local graphics_field
	renderer_fields.skin_graphics.load = function(graphics)
		graphics_field = graphics
		loaded.path = graphics_field.skin.path
		graphics_field.images = {}
		graphics_field.loaded = true
	end

	local selected = renderer:getSkin()
	t:eq(selected, skins[2])
	renderer:load()
	t:eq(loaded.path, "skins/two")
	t:eq(renderer.skin_graphics.images.hitcircle, nil)
	t:eq(renderer.skin_graphics.skin, selected)
end

return test
