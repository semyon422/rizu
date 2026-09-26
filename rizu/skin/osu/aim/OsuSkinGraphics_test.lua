local FakeFilesystem = require("fs.FakeFilesystem")
local OsuSkinGraphics = require("rizu.skin.osu.aim.OsuSkinGraphics")

local test = {}

---@param t testing.T
function test.finds_osu_assets_case_insensitively_preferring_density_and_root_assets(t)
	local graphics = OsuSkinGraphics(FakeFilesystem(), {
		path = "skins/example",
		format = "osu",
		files = {
			"HITCIRCLE.png",
			"HitCircle@2x.PNG",
			"approachcircle.png",
			"Textures/reversearrow.png",
			"ReverseArrow.PNG",
			"Textures/sliderendcircle.png",
		},
	})

	local path, density = graphics:findAsset("hitcircle")
	t:eq(path, "skins/example/HitCircle@2x.PNG")
	t:eq(density, 0.5)
	path, density = graphics:findAsset("approachcircle")
	t:eq(path, "skins/example/approachcircle.png")
	t:eq(density, 1)
	path = graphics:findAsset("reversearrow")
	t:eq(path, "skins/example/ReverseArrow.PNG")
	path = graphics:findAsset("sliderendcircle")
	t:eq(path, nil)
	t:eq(graphics:findAsset("unknown"), nil)
end

---@param t testing.T
function test.finds_numbered_slider_ball_frames(t)
	local graphics = OsuSkinGraphics(FakeFilesystem(), {
		path = "skins/animated",
		files = {"sliderb0.png", "sliderb1.png", "sliderb1@2x.png", "sliderb2.png", "sliderb4.png"},
	})

	t:tdeq(graphics:findSliderBallAssets(), {
		{path = "skins/animated/sliderb0.png", density = 1},
		{path = "skins/animated/sliderb1@2x.png", density = 0.5},
		{path = "skins/animated/sliderb2.png", density = 1},
	})
end

---@param t testing.T
function test.ignores_assets_in_subfolders_and_requires_animation_frame_zero(t)
	local graphics = OsuSkinGraphics(FakeFilesystem(), {
		path = "skins/example",
		files = {"Textures/hitcircle.png", "sliderb1.png"},
	})

	t:eq(graphics:findAsset("hitcircle"), nil)
	t:tdeq(graphics:findSliderBallAssets(), {})
end

return test
