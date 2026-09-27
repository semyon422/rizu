local OsuManiaHud = require("rizu.skin.osu.mania.OsuManiaHud")

local test = {}

function test.hud_uses_full_viewport_width_but_keeps_combo_over_playfield(t)
	local renderer = {
		getFieldTransform = function(_, width, height)
			local scale = math.min(width / 640, height / 480)
			return scale, (width - 640 * scale) / 2, (height - 480 * scale) / 2
		end,
	}
	local hud = setmetatable({}, {__index = OsuManiaHud})
	local right_x, combo_center_x, top_y, scale = hud:getLayout(renderer, 1920, 1080, 170, 260)

	t:aeq(right_x * scale, 1920, 1e-6)
	t:aeq((combo_center_x - (170 + 260 / 2)) * scale, 240, 1e-6)
	t:aeq(top_y * scale, 0, 1e-6)
end

function test.progress_arc_covers_current_positive_and_negative_progress(t)
	local start, finish = OsuManiaHud.getProgressArc(0)
	t:aeq(start, -math.pi / 2, 1e-9)
	t:aeq(finish, start, 1e-9)

	start, finish = OsuManiaHud.getProgressArc(0.25)
	t:aeq(start, -math.pi / 2, 1e-9)
	t:aeq(finish, 0, 1e-9)

	start, finish = OsuManiaHud.getProgressArc(-0.25)
	t:aeq(start, math.pi, 1e-9)
	t:aeq(finish, math.pi * 1.5, 1e-9)
end

function test.progress_arc_clamps_out_of_range_values(t)
	local start, finish = OsuManiaHud.getProgressArc(3)
	t:aeq(start, -math.pi / 2, 1e-9)
	t:aeq(finish, math.pi * 1.5, 1e-9)

	start, finish = OsuManiaHud.getProgressArc(-3)
	t:aeq(start, -math.pi / 2, 1e-9)
	t:aeq(finish, math.pi * 1.5, 1e-9)
end

return test
