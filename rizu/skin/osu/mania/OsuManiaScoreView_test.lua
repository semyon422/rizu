local FakeFilesystem = require("fs.FakeFilesystem")
local OsuManiaScoreView = require("rizu.skin.osu.mania.OsuManiaScoreView")
local OsuManiaAccuracyView = require("rizu.skin.osu.mania.OsuManiaAccuracyView")
local OsuManiaComboView = require("rizu.skin.osu.mania.OsuManiaComboView")
local OsuManiaJudgeView = require("rizu.skin.osu.mania.OsuManiaJudgeView")
local OsuManiaHitMeterView = require("rizu.skin.osu.mania.OsuManiaHitMeterView")
local OsuManiaProgressView = require("rizu.skin.osu.mania.OsuManiaProgressView")
local OsuManiaSkinGraphics = require("rizu.skin.osu.mania.OsuManiaSkinGraphics")
local OsuManiaBitmapFont = require("rizu.skin.osu.mania.OsuManiaBitmapFont")
local test = {}

local function make_graphics()
	local graphics = OsuManiaSkinGraphics(FakeFilesystem())
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
	local font = OsuManiaBitmapFont(graphics)
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

function test.bitmap_fonts_keep_independent_pools_and_refresh_same_measurement_after_generation(t)
	local graphics = make_graphics()
	local image = {getDimensions = function() return 10, 20 end}
	local next_image = {getDimensions = function() return 30, 40 end}
	local initial_generation = graphics.generation
	graphics.getFrames = function(_, name)
		return {(graphics.generation == initial_generation and image or next_image)}
	end
	local first = OsuManiaBitmapFont(graphics)
	local second = OsuManiaBitmapFont(graphics)
	local width_before = first:measure("12")
	local previous_draw = love.graphics.draw
	love.graphics.draw = function() end
	first:draw("12", 1, 0, 100)
	second:draw("12", 1, 0, 100)
	love.graphics.draw = previous_draw
	graphics.generation = initial_generation + 1
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
	local font = OsuManiaBitmapFont(graphics, "score", 330)
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

function test.combo_parser_preserves_numeric_channels_and_refreshes_layout(t)
	local graphics = make_graphics()
	local initial_generation = graphics.generation
	local fallback_image = {getDimensions = function() return 10, 11 end}
	local loaded_image = {getDimensions = function() return 30, 41 end}
	graphics.getFrames = function()
		return {graphics.generation == initial_generation and fallback_image or loaded_image}
	end
	local view = OsuManiaComboView(graphics)
	view:setSkin({skin_ini = {Fonts = {}, Mania = {{ColourBreak = "-1.5, 128.5, 300, 7"}}}})
	t:aeq(view.break_color[1], 0, 1e-6)
	t:aeq(view.break_color[2], 128.5 / 255, 1e-6)
	t:aeq(view.break_color[3], 1, 1e-6)
	t:aeq(view.width, 6 * 10 * 1.28 * 0.625, 1e-6)
	t:aeq(view.height, 11 * 1.28 * 0.625, 1e-6)
	graphics.generation = initial_generation + 1
	view:refreshSize()
	t:aeq(view.width, 6 * 30 * 1.28 * 0.625, 1e-6)
	t:aeq(view.height, 41 * 1.28 * 0.625, 1e-6)
end

function test.accuracy_format_cache_uses_rounded_display_value(t)
	local value = 0.95
	local source = {accuracy_multiplier = 100, getAccuracy = function() return value end}
	local view = OsuManiaAccuracyView(make_graphics())
	local game = {rhythm_engine = {score_engine = {accuracySource = source}}}
	local old_format = string.format
	local percent_formats = 0
	string.format = function(format, ...)
		if format == "%05.2f%%" then percent_formats = percent_formats + 1 end
		return old_format(format, ...)
	end
	local ok, err = xpcall(function()
		view:update(1, game)
		t:eq(percent_formats, 1)
		value = 0.95004
		view:update(1, game)
		t:eq(percent_formats, 1)
		value = 0.95006
		view:update(1, game)
		t:eq(percent_formats, 2)
		t:eq(view.display_text, "95.01%")
	end, debug.traceback)
	string.format = old_format
	if not ok then error(err) end
end

function test.uses_osu_score_bitmap_font_and_layout(t)
	local view = OsuManiaScoreView(make_graphics())
	view.bitmap_font.getImage = function(_, suffix)
		return {getDimensions = function() return 20, 32 end}
	end
	local font = view.bitmap_font
	font.measure = function(_, value)
		local dimensions = value == "00000000" and {144, 32} or {24, 32}
		return dimensions[1], dimensions[2]
	end
	view:setSkin({skin_ini = {Fonts = {ScorePrefix = "digits", ScoreOverlap = "2"}}})
	t:eq(view.score_prefix, "digits")
	t:eq(view.score_overlap, 2)
	t:aeq(view.width, 86.4, 1e-6)
	t:eq(view.height, 19.2)
	t:tdeq(view:getImageAssets(), {
		"digits-0", "digits-1", "digits-2", "digits-3", "digits-4", "digits-5", "digits-6", "digits-7",
		"digits-8", "digits-9", "digits-dot", "digits-comma", "digits-percent", "digits-slash", "digits-fps",
		"digits-ms", "digits-hz",
	})
end

function test.animates_score_and_accuracy_towards_the_latest_values(t)
	local score_source = {score_multiplier = 1, getScore = function() return 1000 end}
	local accuracy_source = {accuracy_multiplier = 100, getAccuracy = function() return 0.987654 end}
	local game = {rhythm_engine = {score_engine = {scoreSource = score_source, accuracySource = accuracy_source}}}
	local view = OsuManiaScoreView(make_graphics())
	view:load(game)
	t:eq(view.has_score, true)
	t:eq(view.score, 0)
	local accuracy_view = OsuManiaAccuracyView(make_graphics())
	accuracy_view:load(game)
	t:eq(accuracy_view.has_accuracy, true)
	t:eq(accuracy_view.accuracy, 0)
	view:update(1 / 60, game)
	accuracy_view:update(1 / 60, game)
	t:aeq(view.score, 250, 1e-6)
	t:aeq(accuracy_view.accuracy, 49.385, 1e-6)
	view:update(1, game)
	accuracy_view:update(1, game)
	t:aeq(view.score, 1000, 0.5)
	t:aeq(accuracy_view.accuracy, 98.77, 1e-6)
end

function test.draws_score_with_bitmap_glyphs(t)
	local view = OsuManiaScoreView(make_graphics())
	view.score = 12345678
	view.has_score = true
	local previous_draw = love.graphics.draw
	local drawn = 0
	love.graphics.draw = function() drawn = drawn + 1 end
	local ok, err = xpcall(function() view:draw() end, debug.traceback)
	love.graphics.draw = previous_draw
	if not ok then error(err) end
	t:eq(drawn, 8)
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
			getDimensions = function() return base:getDimensions() end,
		}}
	end
	graphics.getImageDensity = function() error("draw should rely on LÖVE's image DPI scale") end
	local view = OsuManiaScoreView(graphics)
	view.bitmap_font.getImage = function(_, suffix)
		return graphics:getFrames("score-" .. suffix)[1]
	end
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
	t:aeq(draws[1].sx, 0.6, 1e-6)
	t:aeq(draws[1].x, view.width - (8 * 20 - 7 * 8) * 0.6, 1e-6)
	t:aeq(draws[2].x - draws[1].x, 7.2, 1e-6)
end

function test.combo_uses_same_bitmap_font_with_independent_skin_font_settings(t)
	local view = OsuManiaComboView(make_graphics())
	view:setSkin({skin_ini = {Fonts = {ComboPrefix = "digits", ComboOverlap = "1"}}})
	view.display_combo = 123
	view.alpha = 1
	local previous_draw = love.graphics.draw
	local drawn = 0
	love.graphics.draw = function() drawn = drawn + 1 end
	local ok, err = xpcall(function() view:draw() end, debug.traceback)
	love.graphics.draw = previous_draw
	if not ok then error(err) end
	t:eq(drawn, 3)
	t:eq(view.bitmap_font.prefix, "digits")
	t:eq(view.bitmap_font.overlap, 1)
end

function test.animates_accuracy_in_its_own_bitmap_font_view(t)
	local source = {accuracy_multiplier = 100, getAccuracy = function() return 0.95 end}
	local view = OsuManiaAccuracyView(make_graphics())
	view:load({rhythm_engine = {score_engine = {accuracySource = source}}})
	view:update(1 / 60, {rhythm_engine = {score_engine = {accuracySource = source}}})
	t:aeq(view.accuracy, 47.5, 1e-6)
end

function test.animates_combo_towards_score_combo_source_and_runs_break_effect(t)
	local combo = 0
	local source = {getCombo = function() return combo end}
	local view = OsuManiaComboView(make_graphics())
	view:load({rhythm_engine = {score_engine = {comboSource = source}}})
	combo = 3
	view:update(0)
	t:eq(view.display_combo, 1)
	t:eq(view.scale_y, 1.4)
	combo = 0
	view:update(0)
	t:eq(view.breaking, true)
	t:eq(view.break_combo, 1)
	t:eq(view.display_combo, 0)
	view:update(0.2)
	t:eq(view.display_combo, 0)
	t:eq(view.breaking, false)
end

function test.resets_combo_state_while_break_animation_is_playing(t)
	local combo = 0
	local source = {getCombo = function() return combo end}
	local view = OsuManiaComboView(make_graphics())
	view:load({rhythm_engine = {score_engine = {comboSource = source}}})

	combo = 100
	view:update(0)
	t:eq(view.display_combo, 100)

	combo = 0
	view:update(0)
	t:eq(view.breaking, true)
	t:eq(view.display_combo, 0)

	-- A second miss leaves the source at zero and must not leave stale display state.
	view:update(0.1)
	t:eq(view.display_combo, 0)
	t:eq(view.breaking, true)

	-- The next hit should start counting from zero even before the animation ends.
	combo = 1
	view:update(0)
	t:eq(view.display_combo, 1)
	t:eq(view.breaking, false)
end

function test.judge_animation_maps_osu_mania_grades(t)
	local view = OsuManiaJudgeView(make_graphics())
	local names = {"perfect", "great", "good", "ok", "meh", "miss"}
	local source = {getKey = function() return "score" end, getJudgeNames = function() return names end}
	local score_engine = {sequence = {{score = {visual_judge = 6, judge_index = 6}}}, judgesSource = source}
	local game = {rhythm_engine = {score_engine = score_engine}}
	view:load(game)
	view:update(0, game)
	t:eq(view.grade, 6)
	t:eq(view.elapsed, 0)
	view:update(view.duration, game)
	t:eq(view.elapsed, view.duration)
end

function test.judge_uses_osu_mania_sprite_scale(t)
	local view = OsuManiaJudgeView(make_graphics())
	local source = {
		getKey = function() return "score" end,
		getJudgeNames = function() return {"perfect", "great", "good", "ok", "meh", "miss"} end,
	}
	local score_engine = {sequence = {{score = {visual_judge = 1}}}, judgesSource = source}
	local game = {rhythm_engine = {score_engine = score_engine}}
	view:load(game)
	view:update(0, game)
	view:update(0.08, game)

	local previous_draw = love.graphics.draw
	local draw_scale
	love.graphics.draw = function(_, _, _, _, scale)
		draw_scale = scale
	end
	local ok, err = xpcall(function() view:draw() end, debug.traceback)
	love.graphics.draw = previous_draw
	if not ok then error(err) end
	t:aeq(draw_scale, 480 / 768, 1e-6)
end
function test.hit_meter_advances_colored_blocks_and_progress_pie_draws(t)
	local source = {getKey = function() return "score" end,
		getJudgeNames = function() return {"perfect", "great", "good", "ok", "meh", "miss"} end}
	local score_engine = {sequence = {{score = {visual_judge = 3}}}, judgesSource = source}
	local meter = OsuManiaHitMeterView()
	local game = {rhythm_engine = {score_engine = score_engine}}
	meter:load(game)
	meter:update(0, game)
	t:eq(meter.icons[1].alpha, 1)
	t:eq(meter.icons[1].color[1], 0.85)
	local progress = OsuManiaProgressView()
	progress:update(0, {rhythm_engine = {getProgress = function() return 0.5 end}})
	t:eq(progress.progress, 0.5)
end


function test.positions_hud_score_against_the_full_viewport_edge(t)
	local renderer = require("rizu.skin.osu.OsuManiaRenderer")({fs = require("fs.FakeFilesystem")()}, "4key")
	local hud = renderer.foreground_hud
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
	local conveyor_width = select(4, renderer:getPlayfieldLayout())
	local combo_center = renderer.combo_view:getWorldTransform(
		conveyor_width, 480, renderer.conveyor_hud_transform
	):transformPoint(renderer.combo_view.width / 2, renderer.combo_view.height / 2)
	t:aeq(combo_center, (136 + 120 / 2) * 1.5, 1e-3)
	renderer:unload()
end

return test
