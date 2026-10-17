local OsuFruitsGraphics = require("rizu.skin.osu.fruits.OsuFruitsGraphics")

local test = {}

---@param t testing.T
function test.finds_root_fruits_assets_case_insensitively_and_prefers_high_density(t)
	local graphics = OsuFruitsGraphics(nil, {
		path = "skins/example",
		files = {
			"fruit-apple.png",
			"FRUIT-APPLE@2X.PNG",
			"fruit-drop.png",
			"nested/fruit-pear.png",
		},
	})

	local path, density = graphics:findAsset("fruit-apple")
	t:eq(path, "skins/example/FRUIT-APPLE@2X.PNG")
	t:eq(density, 0.5)
	path, density = graphics:findAsset("fruit-drop")
	t:eq(path, "skins/example/fruit-drop.png")
	t:eq(density, 1)
	t:eq(graphics:findAsset("fruit-pear"), nil)
end

---@param t testing.T
function test.finds_contiguous_catcher_animation_frames_and_prefers_high_density(t)
	local graphics = OsuFruitsGraphics(nil, {
		path = "skins/animated",
		files = {
			"fruit-catcher-idle-0.png",
			"fruit-catcher-idle-1.png",
			"fruit-catcher-idle-1@2x.png",
			"fruit-catcher-idle-3.png",
			"nested/fruit-catcher-idle-2.png",
		},
	})

	t:tdeq(graphics:findAnimationAssets("fruit-catcher-idle"), {
		{path = "skins/animated/fruit-catcher-idle-0.png", density = 1},
		{path = "skins/animated/fruit-catcher-idle-1@2x.png", density = 0.5},
	})
end

return test
