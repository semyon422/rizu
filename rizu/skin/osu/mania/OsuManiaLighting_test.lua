local OsuManiaLighting = require("rizu.skin.osu.mania.OsuManiaLighting")
local OsuManiaRenderer = require("rizu.skin.osu.OsuManiaRenderer")

local test = {}

---@param mode "stage"|"hold"|"oneshot"
---@return rizu.skin.osu.mania.OsuManiaLighting
local function make_lighting(mode)
	return OsuManiaLighting({
		frames = {{getDimensions = function() return 16, 16 end}},
		mode = mode, frame_rate = 30, width = 16, scale_y = 1,
		color = {1, 1, 1, 1}, blend_mode = {"add", "alphamultiply"},
		origin_x = 0.5, origin_y = 1, fade_in = 0.08, fade_out = 0.12,
	})
end

---@param t testing.T
function test.repeated_hold_release_calls_do_not_restart_fade(t)
	local lighting = make_lighting("hold")
	lighting:setHeld(true)
	lighting:update(0.08)
	t:eq(lighting.alpha, 1)
	for _ = 1, 8 do
		lighting:setHeld(false)
		lighting:update(0.02)
	end
	t:eq(lighting.active, false)
	t:eq(lighting.fading, false)
	t:eq(lighting.alpha, 0)
	lighting:setHeld(false)
	t:eq(lighting.active, false)
end

---@param t testing.T
function test.repeated_stage_release_preserves_fade_duration_and_progress(t)
	local lighting = make_lighting("stage")
	lighting:setHeld(true)
	lighting:setHeld(false, 0.2)
	lighting:update(0.05)
	lighting:setHeld(false, 1)
	t:aeq(lighting.fade_elapsed, 0.05, 1e-6)
	t:aeq(lighting.fade_duration, 0.2, 1e-6)
	lighting:update(0.15)
	t:eq(lighting.active, false)
	t:eq(lighting.alpha, 0)
	t:eq(lighting.scale_factor, 0)
end

---@param t testing.T
function test.holding_again_cancels_release_fade(t)
	local lighting = make_lighting("hold")
	lighting:setHeld(true)
	lighting:update(0.08)
	lighting:setHeld(false)
	lighting:update(0.04)
	lighting:setHeld(true)
	t:eq(lighting.fading, false)
	t:eq(lighting.held, true)
	lighting:update(0.2)
	t:eq(lighting.active, true)
	t:eq(lighting.alpha, 1)
end

---@param t testing.T
function test.renderer_long_note_tail_release_finishes_hit_lighting(t)
	local hold = make_lighting("hold")
	local short = make_lighting("oneshot")
	local renderer = setmetatable({
		columns = 1, input_map = {key1 = 1}, active_long = {},
		lighting_notes = setmetatable({}, {__mode = "k"}),
		hit_lightings = {{long = hold, short = short}},
	}, {__index = OsuManiaRenderer})
	local state = "startPassedPressed"
	local note = {
		type = "long",
		getColumn = function() return "key1" end,
		getState = function() return state end,
	}
	local notes = {note}
	renderer:updateHitLightings(notes)
	hold:update(0.08)
	t:eq(hold.held, true)
	state = "endPassed"
	for _ = 1, 12 do
		renderer:updateHitLightings(notes)
		hold:update(0.02)
		short:update(0.02)
	end
	t:eq(hold.held, false)
	t:eq(hold.active, false)
	t:eq(hold.alpha, 0)
	t:eq(short.active, false)
	renderer:updateHitLightings({})
	t:eq(hold.active, false)
end

return test
