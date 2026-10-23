local FakeFilesystem = require("fs.FakeFilesystem")
local BitmapFont = require("rizu.skin.BitmapFont")
local SkinTextures = require("rizu.skin.SkinTextures")

local test = {}

local function image(width, height)
	return {
		getDimensions = function() return width, height end,
		getWidth = function() return width end,
		getHeight = function() return height end,
	}
end

function test.bitmap_font_pool_capacity_is_stable_after_warmup(t)
	local graphics = SkinTextures(FakeFilesystem())
	local glyph_image = image(16, 24)
	graphics.getFrames = function() return {glyph_image} end
	local font = BitmapFont(graphics)
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
	local graphics = SkinTextures(fs, {
		path = "skins/example", files = {"digits-1.png", "score-2.png"},
	})
	local custom, skin_default, bundled = image(10, 20), image(12, 20), image(16, 24)
	graphics.images["skins/example/digits-1.png"] = custom
	graphics.images["skins/example/score-2.png"] = skin_default
	graphics.fallback_file_map = {['score-0@2x.png'] = "archive/score-0@2x.png"}
	graphics.images["archive/score-0@2x.png"] = bundled
	graphics.loaded = true
	local font = BitmapFont(graphics, "digits")
	t:eq(font:getImage("1"), custom)
	t:eq(font:getImage("2"), skin_default)
	t:eq(font:getImage("0"), bundled)
end

local function make_graphics()
	local graphics = SkinTextures(FakeFilesystem())
	local image = {
		getWidth = function() return 20 end,
		getHeight = function() return 32 end,
		getDimensions = function() return 20, 32 end,
	}
	graphics.getFrames = function() return {image} end
	graphics.getAnimationFrames = function(_, name, fallback)
		return {image}
	end
	graphics.getImageDensity = function() return 1 end
	return graphics
end

function test.bitmap_font_reuses_glyph_records_and_clears_shorter_tails(t)
	local graphics = make_graphics()
	local font = BitmapFont(graphics)
	local previous_draw = love.graphics.draw
	love.graphics.draw = function() end
	font:draw("123456", 1, 0, 100)
	local first, third = font.glyphs[1], font.glyphs[3]
	font:draw("12", 1, 0, 100)
	love.graphics.draw = previous_draw
	t:eq(font.glyphs[1], first)
	t:eq(font.glyphs[3], third)
	t:eq(font.glyph_count, 2)
	t:eq(font.glyphs[3].image, nil)
	t:eq(font.glyphs[3].width, nil)
end

function test.bitmap_fonts_keep_independent_pools_and_reload_same_measurement(t)
	local graphics = make_graphics()
	local image = {getDimensions = function() return 10, 20 end}
	local next_image = {getDimensions = function() return 30, 40 end}
	local loaded = false
	graphics.getFrames = function(_, name)
		return {loaded and next_image or image}
	end
	local first = BitmapFont(graphics)
	local second = BitmapFont(graphics)
	local width_before = first:measure("12")
	local previous_draw = love.graphics.draw
	love.graphics.draw = function() end
	first:draw("12", 1, 0, 100)
	second:draw("12", 1, 0, 100)
	love.graphics.draw = previous_draw
	loaded = true
	first:load()
	second:load()
	local width_after = first:measure("12")
	t:assert(first.glyphs ~= second.glyphs)
	t:assert(first.glyphs[1] ~= second.glyphs[1])
	t:eq(width_before, 20)
	t:eq(width_after, 60)
end

function test.bitmap_font_applies_overlap_between_adjacent_glyphs_only(t)
	local graphics = make_graphics()
	local image = {getDimensions = function() return 350, 350 end}
	graphics.getFrames = function() return {image} end
	local font = BitmapFont(graphics, "score", 330)
	t:eq(font:measure("00"), 370)
	local previous_draw = love.graphics.draw
	local draws = {}
	love.graphics.draw = function(_, x) draws[#draws + 1] = x end
	local ok, err = xpcall(function() font:draw("00", 1, 0, 370) end, debug.traceback)
	love.graphics.draw = previous_draw
	if not ok then error(err) end
	t:eq(#draws, 2)
	t:eq(draws[1], 0)
	t:eq(draws[2], 20)
end

---@param t testing.T
function test.assets_request_every_glyph_with_score_fallbacks(t)
	local assets = BitmapFont.getAssets("digits", "hud")
	t:eq(#assets, 18)
	t:tdeq(assets[1], {name = "digits-0", fallback = "score-0", group = "hud"})
	local names = {}
	for _, asset in ipairs(assets) do names[asset.name] = true end
	t:assert(names["digits-percent"] and names["digits-x"] and names["digits-9"])
end

return test
