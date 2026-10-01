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

return test
