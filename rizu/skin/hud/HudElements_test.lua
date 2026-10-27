local FakeFilesystem = require("fs.FakeFilesystem")
local SkinTextures = require("rizu.skin.SkinTextures")
local HudElement = require("rizu.skin.hud.HudElement")
local HudElements = require("rizu.skin.hud.HudElements")
local HudLayout = require("rizu.skin.hud.HudLayout")
local Judgement = require("rizu.skin.hud.elements.Judgement")

local test = {}

---@param width number?
---@param height number?
local function make_textures(width, height)
	local textures = SkinTextures(FakeFilesystem())
	local image = {getDimensions = function() return width or 20, height or 32 end}
	local requested = {}
	textures.getFrames = function(_, name)
		requested[#requested + 1] = name
		return {image}
	end
	textures.getAnimationFrames = function(_, name)
		requested[#requested + 1] = name
		return {image}
	end
	return textures, requested
end

---@param state table
---@return rizu.api.GameApi
local function make_api(state)
	state.judgements = state.judgements or {}
	return {gameplay = {
		getScore = function() return state.score, state.score and tostring(state.score), state.score end,
		getAccuracy = function()
			if state.accuracy then return state.accuracy, ("%0.02f%%"):format(state.accuracy * 100), state.accuracy * 100 end
		end,
		getCombo = function() return state.combo end,
		getJudgeNames = function() return state.names or {"perfect", "great", "good", "ok", "meh", "miss"} end,
		getJudgementCount = function() return #state.judgements end,
		getJudgement = function(_, i)
			local judgement = state.judgements[i]
			return judgement.kind or "hit", judgement.delta or 0, judgement.judge
		end,
		getJudgeWindows = function() return state.windows end,
		getProgress = function() return state.progress or 0 end,
	}} --[[@as rizu.api.GameApi]]
end

---@param name string
---@param values table?
---@param textures rizu.skin.SkinTextures?
---@return any
local function create(name, values, textures)
	return assert(HudElements.get(name))(values, textures or make_textures())
end

---@param t testing.T
function test.invalid_layout_values_take_field_defaults(t)
	local score = create("score", {
		x = 1e9, y = "a", anchor = "nowhere", scale = 0 / 0, digits = 3.5,
		color = {2, 0.5, -1}, animation = "spin", unknown = true,
	})
	t:eq(score.values.type, "score")
	t:eq(score.values.x, 640)
	t:eq(score.values.y, 0)
	t:eq(score.values.anchor, "top_right") -- the score's own default
	t:eq(score.values.scale, 1)
	t:eq(score.values.digits, 4)
	t:tdeq(score.values.color, {1, 0.5, 0, 1})
	t:eq(score.values.animation, "none")
	t:eq(score.values.unknown, nil)
	t:eq(score.x, 640)
	t:eq(score.anchor, "top_right")
end

---@param t testing.T
function test.set_validates_and_reports_texture_changes(t)
	local judgement = create("judgement")
	t:eq(judgement:set("y", 12), false)
	t:eq(judgement.y, 12)
	t:eq(judgement:set("texture_1", "judges/marvelous"), true)
	t:has_error(function() judgement:set("animation", "spin") end)
	t:has_error(function() judgement:set("missing", 1) end)
	judgement:set("scale", 2)
	local x = judgement.transform:transformPoint(1, 0)
	t:eq(x, 2)
	judgement:set("rotation", -90)
	local rx, ry = judgement.transform:transformPoint(1, 0)
	t:eq(math.floor(rx * 2 + 0.5), 0)
	t:eq(math.floor(ry * 2 + 0.5), -4) -- scale 2, turned up
end

---@param t testing.T
function test.layout_builds_known_elements_and_serializes_back(t)
	local textures = make_textures()
	local elements = HudLayout.build({
		screen = {{type = "score", x = -6, font = "digits"}, {type = "future_element"}},
		conveyor = {{type = "sprite", texture = ""}, {type = "combo", y = 111}},
	}, textures)
	t:eq(#elements.screen, 1)
	t:eq(#elements.conveyor, 2)
	local data = HudLayout.serialize(elements)
	t:eq(data.screen[1].type, "score")
	t:eq(data.screen[1].x, -6)
	t:eq(data.conveyor[2].y, 111)
	local again = HudLayout.serialize(HudLayout.build(data, textures))
	t:tdeq(again, data)

	local only_screen = HudLayout.build(data, textures, {"screen"})
	t:eq(only_screen.conveyor, nil)

	local names = {}
	for _, asset in ipairs(HudLayout.getAssets(elements)) do
		t:eq(asset.group, HudElement.group)
		t:assert(asset.name ~= "")
		names[asset.name] = true
	end
	t:assert(names["digits-0"] and names["score-0"])
end

---@param t testing.T
function test.score_and_accuracy_roll_towards_the_latest_values(t)
	local state = {score = 1000, accuracy = 0.987654}
	local api = make_api(state)
	local score = create("score", {digits = 8, animation = "osu"})
	local accuracy = create("accuracy", {animation = "osu"})
	score:load(api)
	accuracy:load(api)
	score:update(1 / 60, api)
	accuracy:update(1 / 60, api)
	t:aeq(score.number_state.value, 250, 1e-6)
	t:eq(score.text, "00000250")
	t:aeq(accuracy.number_state.value, 49.385, 1e-6)
	t:eq(accuracy.text:sub(-1), "%")
	score:update(1, api)
	accuracy:update(1, api)
	t:eq(score.text, "00001000")
	t:eq(accuracy.text, "98.77%")
	t:eq(score.width, 8 * 20)

	local plain = create("score")
	plain:load(api)
	plain:update(0, api)
	t:eq(plain.text, "1000")
	state.score = nil
	plain:update(0, api)
	t:eq(plain.text, "")
end

---@param t testing.T
function test.combo_counts_up_and_restarts_from_zero_during_a_break(t)
	local state = {combo = 0}
	local api = make_api(state)
	local combo = create("combo", {animation = "osu"})
	combo:load(api)
	state.combo = 3
	combo:update(0, api)
	t:eq(combo.combo_state.shown, 1)
	t:eq(combo.combo_state.scale_y, 1.4)
	state.combo = 0
	combo:update(0, api)
	t:eq(combo.combo_state.breaking, true)
	t:eq(combo.combo_state.shown, 1)
	combo:update(0.2, api)
	t:eq(combo.combo_state.breaking, false)
	t:eq(combo.text, "")

	state.combo = 100
	combo:update(0, api)
	t:eq(combo.combo_state.shown, 100)
	state.combo = 0
	combo:update(0, api)
	combo:update(0.1, api)
	t:eq(combo.combo_state.breaking, true)
	t:eq(combo.text, "100")
	state.combo = 1
	combo:update(0, api)
	t:eq(combo.combo_state.breaking, false)
	t:eq(combo.text, "1")

	local plain = create("combo")
	plain:load(api)
	plain:update(0, api)
	t:eq(plain.text, "1")
	t:eq(plain.combo_state.alpha, 1)
end

---@param t testing.T
function test.judgement_grades_follow_the_place_of_the_judge(t)
	t:eq(Judgement.getGrade(1, 6), 1)
	t:eq(Judgement.getGrade(5, 6), 5)
	t:eq(Judgement.getGrade(6, 6), 6)
	t:eq(Judgement.getGrade(4, 5), 4)
	t:eq(Judgement.getGrade(5, 5), 6) -- "poor" of five judges is the miss
	t:eq(Judgement.getGrade(-1, 6), 6)
end

---@param t testing.T
function test.judgement_prefers_sprites_named_after_the_judge(t)
	local textures, requested = make_textures(40, 20)
	local state = {judgements = {{judge = 2}}, names = {"pgreat", "great", "good", "bad", "poor"}}
	local api = make_api(state)
	local judgement = create("judgement", {name_prefix = "judges/", texture_2 = "judges/perfect"}, textures)
	local names = {}
	for _, asset in ipairs(judgement:getAssets()) do names[asset.name] = asset.animation end
	t:eq(names["judges/pgreat"], true)
	t:eq(names["judges/perfect"], true)
	judgement:load(api)
	judgement:update(0, api)
	t:eq(requested[#requested], "judges/great")
	t:eq(judgement.judgement_state.grade, 2)
	t:eq(judgement.width, 40)
end

---@param t testing.T
function test.judgement_animation_plays_and_ends(t)
	local state = {judgements = {{judge = 6}}}
	local api = make_api(state)
	local judgement = create("judgement", {animation = "osu"})
	judgement:load(api)
	judgement:update(0, api)
	t:eq(judgement.judgement_state.grade, 6)
	t:eq(judgement.judgement_state.elapsed, 0)
	t:assert(judgement:getAlpha() >= 0)

	state.judgements[2] = {judge = 1}
	judgement:update(0.08, api)
	local previous_draw = love.graphics.draw
	local draw_scale
	love.graphics.draw = function(_, _, _, _, scale) draw_scale = scale end
	local ok, err = xpcall(function() judgement:draw() end, debug.traceback)
	love.graphics.draw = previous_draw
	if not ok then error(err) end
	t:aeq(draw_scale, 0.8, 1e-6) -- the layout scale is applied by the view transform

	judgement:update(0.22, api)
	t:eq(judgement:getAlpha(), 0)
	state.judgements = {}
	judgement:update(0, api)
	t:eq(judgement.judgement_count, 0)
end

---@param t testing.T
function test.hit_error_rolls_judgement_blocks_and_fades_after_idle(t)
	local state = {judgements = {{judge = 3}}}
	local api = make_api(state)
	local meter = create("osu_hit_error", {mode = "judgements"})
	meter:load(api)
	meter:update(0, api)
	local lit = 0
	for _, icon in ipairs(meter.icons) do
		if icon.alpha > 0 then lit = lit + 1 end
	end
	t:eq(lit, 1)
	t:eq(meter.icons[1].color[1], 0.85)
	meter:update(5, api)
	t:assert(meter.icons[1].alpha < 1)
end

---@param t testing.T
function test.hit_error_timing_mode_tracks_the_delta(t)
	local state = {
		judgements = {{judge = 2, delta = 0.08}, {judge = 6, kind = "miss"}},
		windows = {0.016, 0.064, 0.097, 0.127, 0.151, 0.188},
	}
	local api = make_api(state)
	local meter = create("osu_hit_error", {mode = "timing"})
	meter:load(api)
	meter:update(0, api)
	t:eq(meter.point_index, 1)
	t:eq(meter.range, 0.151)
	t:aeq(meter.width, 0.151 * 1000 * 1.6, 1e-6)
	t:assert(meter.target_position > meter.width / 2)
end

---@param t testing.T
function test.progress_pie_restores_the_blend_mode(t)
	local api = make_api({progress = 0.5})
	local progress = create("osu_radial_progress")
	progress:load(api)
	progress:update(0, api)
	t:eq(progress.progress, 0.5)
	local lg = love.graphics
	local saved = {arc = lg.arc, circle = lg.circle, getBlendMode = lg.getBlendMode, setBlendMode = lg.setBlendMode}
	local blend_mode, alpha_mode = "alpha", "alphamultiply"
	local arc_type
	lg.circle = function() end
	lg.getBlendMode = function() return blend_mode, alpha_mode end
	lg.setBlendMode = function(mode, alpha) blend_mode, alpha_mode = mode, alpha end
	lg.arc = function(_, kind) arc_type = kind end
	local ok, err = xpcall(function() progress:draw() end, debug.traceback)
	for name, value in pairs(saved) do lg[name] = value end
	if not ok then error(err) end
	t:eq(blend_mode, "alpha")
	t:eq(alpha_mode, "alphamultiply")
	t:eq(arc_type, "pie")
end

---@param t testing.T
function test.textures_are_acquired_on_load_and_dropped_on_unload(t)
	local textures, requested = make_textures(40, 30)
	local api = make_api({})
	local sprite = create("sprite", {texture = "panel"}, textures)
	t:eq(#requested, 0)
	sprite:load(api)
	t:eq(requested[1], "panel")
	t:eq(sprite.width, 40)
	sprite:unload(api)
	t:eq(sprite.image, nil)
	local box = create("box", {width = 30, height = 5})
	t:eq(box.width, 30)
	t:eq(#box:getAssets(), 0)
end

---@param t testing.T
function test.arcade_gauge_flickers_under_the_top_segment(t)
	local is_lit = HudElements.get("arcade_gauge").is_lit
	local function lit(count, off)
		local s = ""
		for i = 1, 6 do s = s .. (is_lit(count, off, i) and "#" or ".") end
		return s
	end
	t:eq(lit(0, 0), "......")
	t:eq(lit(4, 0), "####..")
	t:eq(lit(4, 2), "#..#..")
	t:eq(lit(6, 1), "####.#")
end

return test
