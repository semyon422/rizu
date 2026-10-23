---Animation presets of HUD elements, one table per element kind. An element keeps a state table and
---picks a preset by the name in its `animation` field. Add other games' animations as new entries.
local Animations = {}

---@class rizu.skin.hud.Animations.ComboState
---@field shown integer Combo to draw.
---@field alpha number
---@field scale_x number
---@field scale_y number
---@field breaking boolean The combo was just lost: draw `shown` in the break color.
---@field target integer?
---@field display integer?
---@field break_combo integer?
---@field elapsed number?

---@class rizu.skin.hud.Animations.Combo
---@field update fun(state: rizu.skin.hud.Animations.ComboState, dt: number, combo: integer)

local COMBO_INCREASE_DURATION = 0.3
local COMBO_BREAK_DURATION = 0.2
local COMBO_BREAK_SCALE = 4

---@type {[string]: rizu.skin.hud.Animations.Combo}
Animations.combo = {
	none = {update = function(state, _, combo)
		state.shown, state.breaking = combo, false
		state.alpha, state.scale_x, state.scale_y = combo > 0 and 1 or 0, 1, 1
	end},
	-- Counts up one per frame, stretches on every hit and blows up when the combo breaks.
	osu = {update = function(state, dt, combo)
		local previous = state.target or 0
		local display = state.display or 0 ---@type integer
		state.target = combo
		state.elapsed = state.elapsed or 0
		if combo > previous then
			state.breaking = false
			display = combo > previous + 10 and combo or math.max(display, previous)
			state.elapsed, state.alpha = 0, 1
			state.scale_x, state.scale_y = 1, 1.4
		elseif combo < previous and combo == 0 and display > 0 then
			state.breaking, state.break_combo = true, display
			state.elapsed, state.alpha = 0, 0.8
			display = 0
		end
		if not state.breaking and display < combo then display = display + 1 end
		state.display = display

		state.elapsed = state.elapsed + math.max(0, dt)
		if state.breaking then
			local progress = math.min(1, state.elapsed / COMBO_BREAK_DURATION)
			state.alpha = 0.8 * (1 - progress)
			state.scale_x = 1 + (COMBO_BREAK_SCALE - 1) * progress
			state.scale_y = state.scale_x
			if progress >= 1 then state.breaking = false end
		elseif state.elapsed < COMBO_INCREASE_DURATION then
			state.scale_y = 1.4 - 0.4 * state.elapsed / COMBO_INCREASE_DURATION
		else
			state.scale_x, state.scale_y = 1, 1
		end
		if combo == 0 and not state.breaking then state.alpha = math.max(0, state.alpha - dt * 2) end
		state.shown = state.breaking and state.break_combo or display
	end},
}

---@class rizu.skin.hud.Animations.JudgementState
---@field elapsed number Seconds since the judgement.
---@field grade integer 1 is the best hit, 6 the miss.
---@field start_alpha number Opacity of the previous judgement when this one came.
---@field rotation number

---@class rizu.skin.hud.Animations.Judgement
---@field duration number
---@field trigger (fun(state: rizu.skin.hud.Animations.JudgementState))?
---@field get fun(state: rizu.skin.hud.Animations.JudgementState): scale: number, rotation: number, alpha: number

---@param state rizu.skin.hud.Animations.JudgementState
---@param duration number
---@return number
local function osu_judgement_alpha(state, duration)
	-- A new judgement fades in from where the previous one was, so rapid hits don't flicker.
	local progress = state.elapsed / duration
	if progress < 0.08 then return state.start_alpha + (1 - state.start_alpha) * progress / 0.08 end
	return progress > 0.82 and (1 - progress) / 0.18 or 1
end

---@type {[string]: rizu.skin.hud.Animations.Judgement}
Animations.judgement = {
	none = {duration = 0.8, get = function(state)
		return 1, 0, 1 - state.elapsed / 0.8
	end},
	osu = {
		duration = 0.22,
		trigger = function(state)
			state.rotation = state.grade == 6 and (math.random() - 0.5) * 0.2 or 0
		end,
		get = function(state)
			local t = state.elapsed
			local scale ---@type number
			if state.grade == 6 then scale = 1.2 - 0.2 * math.min(1, t / 0.1)
			elseif t < 0.08 then scale = 0.8 + 0.2 * t / 0.08
			elseif t < 0.18 then scale = 1 - 0.3 * (t - 0.08) / 0.1
			else scale = 0.7 - 0.3 * (t - 0.18) / 0.04 end
			return scale, state.rotation, osu_judgement_alpha(state, 0.22)
		end,
	},
	-- osu! timing without the scaling and the miss tilt.
	osu_fade = {duration = 0.22, get = function(state)
		return 1, 0, osu_judgement_alpha(state, 0.22)
	end},
}

---@class rizu.skin.hud.Animations.NumberState
---@field value number? Number to draw, nil before the first update.

---@class rizu.skin.hud.Animations.Number
---@field update fun(state: rizu.skin.hud.Animations.NumberState, dt: number, target: number, rate: number, snap: number)

---@type {[string]: rizu.skin.hud.Animations.Number}
Animations.number = {
	none = {update = function(state, _, target) state.value = target end},
	-- Rolls towards the target, closing `1 - rate` of the distance every 60 Hz frame.
	osu = {update = function(state, dt, target, rate, snap)
		local value = state.value or 0 ---@type number
		local frames = math.max(0, dt) * 60
		if math.abs(value - target) < snap then
			value = target
		elseif frames > 0 then
			value = target + (value - target) * rate ^ frames
		end
		state.value = value
	end},
}

---@param presets {[string]: any}
---@return string[]
function Animations.names(presets)
	local names = {} ---@type string[]
	for name in pairs(presets) do names[#names + 1] = name end
	table.sort(names, function(a, b)
		if a == "none" or b == "none" then return a == "none" and b ~= "none" end
		return a < b
	end)
	return names
end

return Animations
