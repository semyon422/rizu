local FakeFilesystem = require("fs.FakeFilesystem")
local OsuTaikoSkinGraphics = require("rizu.skin.osu.taiko.OsuTaikoSkinGraphics")

local test = {}

---@param t testing.T
function test.finds_taiko_assets_case_insensitively_preferring_high_density_root_files(t)
	local graphics = OsuTaikoSkinGraphics(FakeFilesystem(), {
		path = "skins/example",
		format = "osu",
		files = {
			"TaikoHitCircle.png",
			"taikohitcircle@2x.PNG",
			"taiko-roll-middle.png",
			"Textures/taiko-bar-left.png",
			"TAIKO-BAR-LEFT.PNG",
		},
	})

	t:eq(graphics:findAsset("taikohitcircle"), "skins/example/taikohitcircle@2x.PNG")
	t:eq(graphics:findAsset("roll_middle"), "skins/example/taiko-roll-middle.png")
	t:eq(graphics:findAsset("bar_left"), "skins/example/TAIKO-BAR-LEFT.PNG")
	t:eq(graphics:findAsset("missing"), nil)
end

return test
