local OsuFruitsRenderer = require("rizu.skin.osu.OsuFruitsRenderer")

local test = {}

---@param t testing.T
function test.uses_the_classic_512_by_384_gamefield_and_reverses_viewport_transform(t)
	local renderer = OsuFruitsRenderer({})
	local scale, x, y = renderer:getField(1280, 720)
	t:aeq(scale, 1.5, 1e-9)
	t:aeq(x, 256, 1e-9)
	t:eq(y, 72)

	local transform = {
		inverseTransformPoint = function(_, px, py) return px - 10, py + 20 end,
	}
	local chart_x, chart_y = renderer:toChart(646, 378, 1280, 720, transform)
	t:aeq(chart_x, 253.33333333333334, 1e-9)
	t:aeq(chart_y, 217.33333333333334, 1e-9)

	local field_scale = 1080 / 480
	local wide_scale, wide_x, wide_y = renderer:getField(1920, 1080)
	t:aeq(wide_scale, field_scale, 1e-9)
	t:aeq(wide_x, (1920 - 512 * field_scale) / 2, 1e-9)
	t:aeq(wide_y, (1080 - 384 * field_scale) / 2, 1e-9)
end

---@param t testing.T
function test.selects_the_configured_osu_skin_and_parses_catch_colors(t)
	local skin = {
		path = "skins/fruit",
		skin_ini = {CatchTheBeat = {HyperDash = "12, 34, 56", HyperDashFruit = "78,90,123"}},
	}
	local game = {
		fs = {},
		skinRegistry = {
			getOsuSkin = function(_, path) if path == skin.path then return skin end end,
			getOsuSkins = function() return {skin} end,
		},
		settings = {getStringMap = function() return {["osu/1fruits"] = "skins/fruit/"} end},
	}
	local renderer = OsuFruitsRenderer(game)
	renderer.skin_graphics.load = function(graphics) graphics.loaded = true end
	renderer:load()
	t:eq(renderer.skin_graphics.skin, skin)
	t:tdeq(renderer.hyperdash_color, {12 / 255, 34 / 255, 56 / 255})
	t:tdeq(renderer.hyperdash_fruit_color, {78 / 255, 90 / 255, 123 / 255})
end

return test
