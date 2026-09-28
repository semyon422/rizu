local OsuManiaJudgeView = require("rizu.skin.osu.mania.OsuManiaJudgeView")
local OsuManiaHitMeterView = require("rizu.skin.osu.mania.OsuManiaHitMeterView")
local OsuManiaProgressView = require("rizu.skin.osu.mania.OsuManiaProgressView")
local OsuManiaSkinGraphics = require("rizu.skin.osu.mania.OsuManiaSkinGraphics")
local FakeFilesystem = require("fs.FakeFilesystem")

local test = {}

local function make_graphics()
	local graphics = OsuManiaSkinGraphics(FakeFilesystem())
	local image = {getDimensions = function() return 40, 20 end}
	graphics.getAnimationFrames = function(_, name, fallback)
		return {image}
	end
	return graphics
end

local function make_score_engine(judge)
	local source = {
		getKey = function() return "mania" end,
		getJudgeNames = function() return {"perfect", "great", "good", "ok", "meh", "miss"} end,
	}
	return {
		judgesSource = source,
		comboSource = {getCombo = function() return 7 end},
		sequence = {{mania = {visual_judge = judge, judge_index = judge}}},
	}
end

function test.judge_animation_plays_frames_and_fades(t)
	local graphics = make_graphics()
	local view = OsuManiaJudgeView(graphics)
	local score_engine = make_score_engine(2)
	local game = {rhythm_engine = {score_engine = score_engine}}
	view:load(game)
	view:update(0, game)
	t:eq(view.grade, 2)
	t:eq(view.elapsed, 0)
	t:eq(view.width, 40)
	view:update(0.22, game)
	t:eq(view.elapsed, view.duration)
end

function test.hit_meter_rolls_judge_blocks_and_fades_after_idle(t)
	local view = OsuManiaHitMeterView()
	local score_engine = make_score_engine(3)
	local game = {rhythm_engine = {score_engine = score_engine}}
	view:load(game)
	view:update(0, game)
	local lit = 0
	for _, icon in ipairs(view.icons) do
		if icon.alpha > 0 then lit = lit + 1 end
	end
	t:eq(lit, 1)
	t:eq(view.icons[1].color[1], 0.48)
	view:update(5, game)
	t:assert(view.icons[1].alpha < 1)
end

function test.progress_pie_uses_engine_progress(t)
	local view = OsuManiaProgressView()
	view:update(0, {rhythm_engine = {getProgress = function() return 0.5 end}})
	t:eq(view.progress, 0.5)
	local previous_arc = love.graphics.arc
	local called = false
	love.graphics.arc = function(mode, arc_type, x, y, radius, start_angle, end_angle)
		called = true
		t:eq(mode, "fill")
		t:eq(arc_type, "pie")
	end
	local ok, err = xpcall(function() view:draw() end, debug.traceback)
	love.graphics.arc = previous_arc
	if not ok then error(err) end
	t:eq(called, true)
end

return test
