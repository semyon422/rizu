local OsuAimRenderer = require("rizu.skin.osu.OsuAimRenderer")
local test = {}

---@param t testing.T
function test.loads_the_given_osu_skin_and_uses_sprite_renderers(t)
	local loaded = {}
	local skin = {path = "skins/two", files = {}}
	local game = {
		fs = {},
		rhythm_engine = {rules = {objects = {}}, visual_info = {time = 0}},
	}
	local renderer = OsuAimRenderer(game, skin)
	local renderer_fields = renderer
	renderer_fields.slider_graphics.prepare = function() end
	renderer_fields.slider_graphics.load = function() end
	renderer_fields.skin_graphics.setFallbackArchive = function() end
	renderer_fields.skin_graphics.load = function(graphics, assets)
		loaded.path = graphics.skin.path
		loaded.assets = assets
		graphics.loaded = true
	end

	renderer:load()
	t:eq(loaded.path, "skins/two")
	t:eq(loaded.assets[1].group, "playfield")
	t:eq(renderer.sprites.hitcircle, nil)
	t:eq(renderer.sprites.batch, renderer.skin_graphics.batch)
	t:eq(renderer.skin_graphics.skin, skin)
end

return test
