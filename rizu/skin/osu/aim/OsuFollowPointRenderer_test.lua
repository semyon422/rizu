local OsuFollowPointRenderer = require("rizu.skin.osu.aim.OsuFollowPointRenderer")

local test = {}

---@param rules table
---@param time number
---@return {x: number, y: number, rotation: number, sx: number, alpha: number}[]
local function capture(rules, time)
	local previous_love = love
	local draws = {}
	local alpha = 1
	local frame = {getDimensions = function() return 16, 16 end}
	rawset(_G, "love", {graphics = {
		setColor = function(_, _, _, a) alpha = a end,
		draw = function(_, x, y, rotation, sx)
			draws[#draws + 1] = {x = x, y = y, rotation = rotation, sx = sx, alpha = alpha}
		end,
	}})
	local ok, err = pcall(OsuFollowPointRenderer.draw, rules, time, {followpoint = {frame}})
	rawset(_G, "love", previous_love)
	assert(ok, err)
	return draws
end

---@param objects table[]
local function rules(objects)
	return {objects = objects, sliders = {}, preempt = 1.2, next_index = 1}
end

---@param t testing.T
function test.points_line_up_between_objects_of_one_combo(t)
	local chain = rules({
		{time = 1, x = 0, y = 100, kind = "circle", combo_number = 1},
		{time = 2, x = 160, y = 100, kind = "circle", combo_number = 2},
	})
	-- 160px leaves room for points at 48, 80 and 112; all have settled by now.
	local draws = capture(chain, 1.3)
	t:eq(#draws, 3)
	t:aeq(draws[1].x, 48, 1e-9)
	t:aeq(draws[3].x, 112, 1e-9)
	t:eq(draws[1].y, 100)
	t:eq(draws[1].rotation, 0)
	t:aeq(draws[1].sx, 1, 1e-9)
	t:aeq(draws[1].alpha, 1, 1e-9)

	-- The first point arrives at 1.3 and has half faded out 0.2 later.
	local fading = capture(chain, 1.5)
	t:aeq(fading[1].alpha, 0.5, 1e-9)
	t:eq(#capture(chain, 3), 0)
	t:eq(#capture(chain, -1), 0)
end

---@param t testing.T
function test.new_combos_spinners_and_slider_ends_shape_the_chain(t)
	local objects = {
		{time = 1, x = 0, y = 0, kind = "circle", combo_number = 1},
		{time = 2, x = 160, y = 0, kind = "circle", combo_number = 1},
	}
	t:eq(#capture(rules(objects), 1.2), 0)
	objects[2].combo_number = 2
	objects[1].kind = "spinner"
	t:eq(#capture(rules(objects), 1.2), 0)

	objects[1].kind = "slider"
	local with_slider = rules(objects)
	with_slider.sliders[1] = {
		path = {position = function(_, progress) return 0, progress * 160 end},
		timing = {spans = 1, end_time = 1.5},
	}
	-- Points leave from the slider's end, straight up to the next circle.
	local draws = capture(with_slider, 1.6)
	t:eq(#draws, 5)
	t:aeq(draws[1].rotation, math.atan2(-160, 160), 1e-9)
end

return test
