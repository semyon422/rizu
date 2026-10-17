local OsuManiaJudgeView = require("rizu.skin.osu.mania.views.OsuManiaJudgeView")
local OsuManiaHitMeterView = require("rizu.skin.osu.mania.views.OsuManiaHitMeterView")
local OsuManiaProgressView = require("rizu.skin.osu.mania.views.OsuManiaProgressView")
local OsuSkinGraphics = require("rizu.skin.osu.OsuSkinGraphics")
local FakeFilesystem = require("fs.FakeFilesystem")

local test = {}

local function make_graphics()
	local graphics = OsuSkinGraphics(FakeFilesystem())
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
	t:eq(view.icons[1].color[1], 0.85)
	view:update(5, game)
	t:assert(view.icons[1].alpha < 1)
end

function test.hit_meter_error_mode_tracks_timing_delta(t)
	local view = OsuManiaHitMeterView()
	view:setMode(1)
	t:eq(view.mode, "error")
	t:assert(view.error_mode)
	local source = {
		getKey = function() return "mania" end,
		getJudgeNames = function() return {"perfect", "great", "good", "ok", "meh", "miss"} end,
		judge_windows = {windows = {0.016, 0.064, 0.097, 0.127, 0.151, 0.188}},
	}
	local score_engine = {
		judgesSource = source,
		sequence = {{mania = {visual_judge = 2}, misc = {deltaTime = 0.08}}},
	}
	local game = {rhythm_engine = {score_engine = score_engine}}
	view:load(game)
	view:update(0, game)
	t:eq(view.point_index, 1)
	t:assert(view.target_position > view.width / 2)
	t:eq(view.error_range, 0.151)
end

function test.progress_pie_uses_engine_progress(t)
	local view = OsuManiaProgressView()
	view:update(0, {rhythm_engine = {getProgress = function() return 0.5 end}})
	t:eq(view.progress, 0.5)
	local previous_arc, previous_circle = love.graphics.arc, love.graphics.circle
	local previous_get_blend, previous_set_blend = love.graphics.getBlendMode, love.graphics.setBlendMode
	local blend_mode, alpha_mode = "alpha", "alphamultiply"
	love.graphics.circle = function() end
	love.graphics.getBlendMode = function() return blend_mode, alpha_mode end
	love.graphics.setBlendMode = function(mode, alpha) blend_mode, alpha_mode = mode, alpha end
	local called = false
	love.graphics.arc = function(mode, arc_type, x, y, radius, start_angle, end_angle)
		called = true
		t:eq(mode, "fill")
		t:eq(arc_type, "pie")
	end
	local ok, err = xpcall(function() view:draw() end, debug.traceback)
	love.graphics.arc, love.graphics.circle = previous_arc, previous_circle
	love.graphics.getBlendMode, love.graphics.setBlendMode = previous_get_blend, previous_set_blend
	if not ok then error(err) end
	t:eq(blend_mode, "alpha")
	t:eq(alpha_mode, "alphamultiply")
	t:eq(called, true)
end

return test
