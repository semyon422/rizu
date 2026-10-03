local FakeFilesystem = require("fs.FakeFilesystem")
local OsuManiaBitmapFont = require("rizu.skin.osu.mania.OsuManiaBitmapFont")
local OsuManiaSkinGraphics = require("rizu.skin.osu.mania.OsuManiaSkinGraphics")

local test = {}

local function image(width, height)
	return {
		getDimensions = function() return width, height end,
		getWidth = function() return width end,
		getHeight = function() return height end,
	}
end

function test.bitmap_font_pool_capacity_is_stable_after_warmup(t)
	local graphics = OsuManiaSkinGraphics(FakeFilesystem())
	local glyph_image = image(16, 24)
	graphics.getFrames = function() return {glyph_image} end
	local font = OsuManiaBitmapFont(graphics)
	local previous_draw = love.graphics.draw
	love.graphics.draw = function() end
	font:draw("1234567890", 1, 0, 200)
	local capacity, first = #font.glyphs, font.glyphs[1]
	font:draw("1234567890", 1, 0, 200)
	love.graphics.draw = previous_draw
	t:eq(#font.glyphs, capacity)
	t:eq(font.glyphs[1], first)
end

---@param t testing.T
function test.custom_font_prefix_falls_back_to_score_glyphs(t)
	local fs = FakeFilesystem()
	fs:createDirectory("skins/example")
	local graphics = OsuManiaSkinGraphics(fs, {
		path = "skins/example", files = {"digits-1.png", "score-2.png"},
	})
	local custom, skin_default, bundled = image(10, 20), image(12, 20), image(16, 24)
	graphics.images["skins/example/digits-1.png"] = custom
	graphics.images["skins/example/score-2.png"] = skin_default
	graphics.fallback_file_map = {['score-0@2x.png'] = "archive/score-0@2x.png"}
	graphics.images["archive/score-0@2x.png"] = bundled
	local font = OsuManiaBitmapFont(graphics, "digits")
	t:eq(font:getImage("1"), custom)
	t:eq(font:getImage("2"), skin_default)
	t:eq(font:getImage("0"), bundled)
end

return test
