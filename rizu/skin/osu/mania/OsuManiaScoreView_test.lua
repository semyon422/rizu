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
	t:aeq(view.width, 8 * 18 * 0.6, 1e-6)
	t:aeq(view.height, 32 * 0.6 + 3 + 32 * 0.36, 1e-6)
	t:tdeq(view:getImageAssets(), {
		"digits-0", "digits-1", "digits-2", "digits-3", "digits-4", "digits-5", "digits-6", "digits-7",
		"digits-8", "digits-9", "digits-dot", "digits-percent",
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

return test
