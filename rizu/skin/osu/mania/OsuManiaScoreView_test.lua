local FakeFilesystem = require("fs.FakeFilesystem")
local OsuManiaScoreView = require("rizu.skin.osu.mania.OsuManiaScoreView")
local OsuManiaSkinGraphics = require("rizu.skin.osu.mania.OsuManiaSkinGraphics")

local test = {}

local function make_graphics()
	local graphics = OsuManiaSkinGraphics(FakeFilesystem())
	local images = {}
	for digit = 0, 9 do
		images["score-" .. digit] = {
			getWidth = function() return 20 end,
			getHeight = function() return 32 end,
		}
	end
	images["score-dot"] = {
		getWidth = function() return 8 end,
		getHeight = function() return 32 end,
	}
	images["score-percent"] = {
		getWidth = function() return 24 end,
		getHeight = function() return 32 end,
	}
	graphics.getFrames = function(_, name)
		local suffix = name:match("([^%-]+)$")
		local image = images["score-" .. suffix]
		return image and {image} or {}
	end
	graphics.getImageDensity = function() return 1 end
	return graphics
end

function test.uses_osu_score_bitmap_font_and_layout(t)
	local view = OsuManiaScoreView(make_graphics())
	view:setSkin({skin_ini = {Fonts = {ScorePrefix = "digits", ScoreOverlap = "2"}}})

	t:eq(view.score_prefix, "digits")
	t:eq(view.score_overlap, 2)
	t:aeq(view.width, (8 * 20 - 8 * 2) * 0.75, 1e-6)
	t:aeq(view.height, 32 * 0.75 + 3 + 32 * 0.75 * 0.6, 1e-6)
	t:tdeq(view:getImageAssets(), {
		"digits-0", "digits-1", "digits-2", "digits-3", "digits-4", "digits-5", "digits-6", "digits-7",
		"digits-8", "digits-9", "digits-dot", "digits-comma", "digits-percent", "digits-slash", "digits-fps",
		"digits-ms", "digits-hz",
	})
end

function test.animates_score_and_accuracy_towards_the_latest_values(t)
	local score_source = {
		score_multiplier = 1,
		getScore = function() return 1000 end,
	}
	local accuracy_source = {
		accuracy_multiplier = 100,
		getAccuracy = function() return 0.987654 end,
	}
	local game = {
		rhythm_engine = {
			score_engine = {scoreSource = score_source, accuracySource = accuracy_source},
		},
	}
	local view = OsuManiaScoreView(make_graphics())
	view:load(game)
	t:eq(view.has_score, true)
	t:eq(view.has_accuracy, true)
	t:eq(view.score, 0)
	t:eq(view.accuracy, 0)

	view:update(1 / 60, game)
	t:aeq(view.score, 250, 1e-6)
	t:aeq(view.accuracy, 49.385, 1e-6)
	view:update(1, game)
	t:aeq(view.score, 1000, 0.5)
	t:aeq(view.accuracy, 98.77, 1e-6)
end

function test.draws_score_with_bitmap_glyphs(t)
	local view = OsuManiaScoreView(make_graphics())
	view.score = 12345678
	view.accuracy = 98.76
	view.has_score = true
	view.has_accuracy = true
	local previous_draw = love.graphics.draw
	local drawn = 0
	love.graphics.draw = function() drawn = drawn + 1 end
	local ok, err = xpcall(function() view:draw() end, debug.traceback)
	love.graphics.draw = previous_draw
	if not ok then error(err) end
	t:eq(drawn, 14)
end

function test.uses_skin_overlap_and_love_image_dpi_scaling_once(t)
	local graphics = make_graphics()
	local base_get_frames = graphics.getFrames
	graphics.getFrames = function(self, name)
		local frames = base_get_frames(self, name)
		if #frames == 0 then return frames end
		local base = frames[1]
		return {{
			getWidth = function() return base:getWidth() * 2 end,
			getHeight = function() return base:getHeight() * 2 end,
			getDimensions = function() return base:getWidth(), base:getHeight() end,
		}}
	end
	graphics.getImageDensity = function() error("draw should rely on LÖVE's image DPI scale") end
	local view = OsuManiaScoreView(graphics)
	view:setSkin({skin_ini = {Fonts = {ScorePrefix = "digits", ScoreOverlap = "8"}}})
	view.has_score = true
	view.score = 12345678

	local previous_draw = love.graphics.draw
	local draws = {}
	love.graphics.draw = function(image, x, y, rotation, sx, sy)
		draws[#draws + 1] = {x = x, sx = sx, sy = sy}
	end
	local ok, err = xpcall(function() view:draw() end, debug.traceback)
	love.graphics.draw = previous_draw
	if not ok then error(err) end

	t:eq(#draws, 8)
	t:aeq(draws[1].sx, 0.75, 1e-6)
		t:aeq(draws[1].x, view.width - (8 * 20 - 8 * 8) * 0.75, 1e-6)
		t:aeq(draws[2].x - draws[1].x, 9, 1e-6)
end

function test.positions_hud_score_against_the_full_viewport_edge(t)
	local renderer = require("rizu.skin.osu.OsuManiaRenderer")({fs = require("fs.FakeFilesystem")()}, "4key")
	local hud = renderer.hud
	local native_width, native_height, hud_transform
	local draw_hud = hud.draw
	hud.draw = function(_, width, height, transform)
		native_width, native_height, hud_transform = width, height, transform
	end
	renderer:drawHud(1280, 720, love.math.newTransform())
	hud.draw = draw_hud

	t:aeq(native_width, 1280 / 1.5, 1e-6)
	t:aeq(native_height, 720 / 1.5, 1e-6)
	local score_view = renderer.score_view
	local score_transform = score_view:getWorldTransform(native_width, native_height, hud_transform)
	local right_edge = score_transform:transformPoint(score_view.width, 0)
	t:aeq(right_edge, 1280 - 6 * 1.5, 1e-3)
	renderer:unload()
end

return test
