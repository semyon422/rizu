local OsuManiaLighting = require("rizu.skin.osu.mania.OsuManiaLighting")
local OsuManiaRenderer = require("rizu.skin.osu.OsuManiaRenderer")

local test = {}

---@param mode "stage"|"hold"|"oneshot"
---@return rizu.skin.osu.mania.OsuManiaLighting
local function make_lighting(mode)
	return OsuManiaLighting({
		frames = {{getDimensions = function() return 16, 16 end}},
		mode = mode, frame_rate = 30, width = 16, scale_y = 1,
		color = {1, 1, 1, 1},
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

-- Model automatic batching boundaries, rather than counting lg.draw calls:
-- LÖVE may combine consecutive draws but state/texture changes split the run.
local function with_lighting_graphics(callback)
	local lg = love.graphics
	local draw, push, pop = lg.draw, lg.push, lg.pop
	local get_blend, set_blend = lg.getBlendMode, lg.setBlendMode
	local get_color, set_color = lg.getColor, lg.setColor
	local state = {mode = "alpha", alpha = "alphamultiply", changes = 0, draws = 0, runs = 0}
	local current_image
	lg.getBlendMode = function() return state.mode, state.alpha end
	lg.setBlendMode = function(mode, alpha)
		state.changes = state.changes + 1
		state.mode, state.alpha = mode, alpha
		current_image = nil
	end
	lg.draw = function(image)
		state.draws = state.draws + 1
		if current_image ~= image then state.runs = state.runs + 1 end
		current_image = image
	end
	lg.push, lg.pop = function() error("per-light state push breaks batching") end,
		function() error("per-light state pop breaks batching") end
	lg.getColor = function() return 1, 1, 1, 1 end
	lg.setColor = function() end
	local ok, err = xpcall(function() callback(state) end, debug.traceback)
	lg.draw, lg.push, lg.pop = draw, push, pop
	lg.getBlendMode, lg.setBlendMode = get_blend, set_blend
	lg.getColor, lg.setColor = get_color, set_color
	if not ok then error(err) end
end

local function make_draw_renderer()
	local flushes = 0
	local renderer = setmetatable({
		columns = 4, upside_down = false, light_position = 413,
		stage_lightings = {}, hit_lightings = {},
		skin_graphics = {batch = {flush = function() flushes = flushes + 1 end}},
	}, {__index = OsuManiaRenderer})
	return renderer, function() return flushes end
end

function test.stage_lights_share_automatic_batch_without_redundant_blend_changes(t)
	with_lighting_graphics(function(state)
		local renderer, flushes = make_draw_renderer()
		local image = {getDimensions = function() return 16, 16 end}
		for column = 1, 4 do
			local lighting = make_lighting("stage")
			lighting.frames = {image}
			lighting.color = {column / 4, 1, 1, 1}
			lighting:setHeld(true)
			renderer.stage_lightings[column] = lighting
		end
		renderer:drawStageLightings({30, 30, 30, 30}, {15, 45, 75, 105}, 402)
		t:eq(state.draws, 4)
		t:eq(state.runs, 1)
		t:eq(state.changes, 0)
		t:eq(flushes(), 1)
		t:eq(state.mode, "alpha")
	end)
end

function test.hit_lights_set_additive_blend_once_and_restore_after_all_columns(t)
	with_lighting_graphics(function(state)
		local renderer, flushes = make_draw_renderer()
		local image = {getDimensions = function() return 16, 16 end}
		for column = 1, 4 do
			local lighting = make_lighting("oneshot")
			lighting.frames = {image}
			lighting:trigger()
			lighting:update(0.08)
			renderer.hit_lightings[column] = {short = lighting}
		end
		renderer:drawHitLightings({15, 45, 75, 105}, 402)
		t:eq(state.draws, 4)
		t:eq(state.runs, 1)
		t:eq(state.changes, 2)
		t:eq(flushes(), 1)
		t:eq(state.mode, "alpha")
		t:eq(state.alpha, "alphamultiply")
	end)
end

function test.invisible_lighting_passes_do_not_change_state_or_flush(t)
	with_lighting_graphics(function(state)
		local renderer, flushes = make_draw_renderer()
		for column = 1, 4 do
			renderer.stage_lightings[column] = make_lighting("stage")
			local short = make_lighting("oneshot")
			short:trigger() -- active, but still fully transparent
			renderer.hit_lightings[column] = {short = short, long = make_lighting("hold")}
		end
		renderer:drawStageLightings({30, 30, 30, 30}, {15, 45, 75, 105}, 402)
		renderer:drawHitLightings({15, 45, 75, 105}, 402)
		t:eq(state.draws, 0)
		t:eq(state.changes, 0)
		t:eq(flushes(), 0)
	end)
end

return test
