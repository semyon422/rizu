local FakeFilesystem = require("fs.FakeFilesystem")
local OsuAimSprites = require("rizu.skin.osu.aim.OsuAimSprites")
local SkinTextures = require("rizu.skin.SkinTextures")

local test = {}

---@param assets rizu.skin.SkinTextures.Asset[]
---@return {[string]: rizu.skin.SkinTextures.Asset}
local function byName(assets)
	local map = {}
	for _, asset in ipairs(assets) do map[asset.name] = asset end
	return map
end

---@param t testing.T
function test.packs_every_sprite_into_one_atlas_with_skin_digits_and_numbered_slider_balls(t)
	local graphics = SkinTextures(FakeFilesystem(), {
		path = "skins/example",
		files = {"sliderb0.png", "sliderb1@2x.png", "sliderb3.png"},
		skin_ini = {General = {}, Fonts = {HitCirclePrefix = "fonts\\num"}},
	})
	local assets = OsuAimSprites.getAssets(graphics)
	for _, asset in ipairs(assets) do t:eq(asset.group, "playfield") end

	local map = byName(assets)
	t:assert(map.hitcircle and map.cursor and map.sliderb0 and map.sliderb1)
	-- Animation stops at the first missing frame, and replaces the still image.
	t:eq(map.sliderb3, nil)
	t:eq(map.sliderb, nil)
	t:eq(map["fonts\\num-7"].fallback, "default-7")
end

---@param t testing.T
function test.uses_default_digits_and_still_slider_ball_without_skin_overrides(t)
	local graphics = SkinTextures(FakeFilesystem(), {path = "skins/plain", files = {"sliderb1.png"}})
	local map = byName(OsuAimSprites.getAssets(graphics))
	t:assert(map.sliderb)
	t:eq(map.sliderb1, nil)
	t:assert(map["default-0"] and map["default-9"])
end

---@param t testing.T
function test.slider_end_circle_follows_the_skin_version(t)
	---@param files string[]
	---@param version string?
	local function load(files, version)
		local graphics = SkinTextures(FakeFilesystem(), {
			path = "skins/example", files = files, skin_ini = {General = {Version = version}, Fonts = {}},
		})
		graphics.getFrames = function(_, name)
			for _, file in ipairs(files) do
				if file == name .. ".png" then return {name} end
			end
			return {}
		end
		return OsuAimSprites.load(graphics)
	end
	local circles = {"hitcircle.png", "hitcircleoverlay.png"}

	-- Version 1 skins, and those that do not state a version, reuse the hit circle.
	for _, version in ipairs({false, "1", "1.0"}) do
		local sprites = load(circles, version or nil)
		t:eq(sprites.sliderendcircle, "hitcircle")
		t:eq(sprites.sliderendcircleoverlay, "hitcircleoverlay")
	end
	for _, version in ipairs({"2", "2.5", "latest"}) do
		local sprites = load(circles, version)
		t:eq(sprites.sliderendcircle, nil)
		t:eq(sprites.sliderendcircleoverlay, nil)
	end
	-- A skinned end circle is used at any version, without borrowing an overlay.
	local sprites = load({"hitcircle.png", "hitcircleoverlay.png", "sliderendcircle.png"}, "2.5")
	t:eq(sprites.sliderendcircle, "sliderendcircle")
	t:eq(sprites.sliderendcircleoverlay, nil)
end

---@param t testing.T
function test.reads_skin_colours_with_default_combo_colours(t)
	---@param colours {[string]: string}
	local function load(colours)
		local graphics = SkinTextures(FakeFilesystem(), {
			path = "skins/example", files = {}, skin_ini = {General = {}, Fonts = {}, Colours = colours},
		})
		return OsuAimSprites.load(graphics)
	end

	local plain = load({})
	t:eq(#plain.combo_colors, 4)
	t:eq(plain.slider_border, nil)
	t:eq(plain.slider_track, nil)

	-- Gaps in the numbering are skipped rather than ending the list.
	local skinned = load({Combo1 = "255, 0, 0", Combo3 = "0,0,255", SliderBorder = "0,255,0", SliderTrackOverride = "bad"})
	t:tdeq(skinned.combo_colors, {{1, 0, 0}, {0, 0, 1}})
	t:tdeq(skinned.slider_border, {0, 1, 0})
	t:eq(skinned.slider_track, nil)
end

return test
