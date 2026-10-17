local SliderRenderer = require("rizu.skin.base.osu.aim.SliderRenderer")
local SliderOverlayRenderer = require("rizu.skin.base.osu.aim.SliderOverlayRenderer")

local test = {}

---@param t testing.T
function test.draws_only_the_slider_body(t)
	local draw_args
	local graphics = {
		draw = function(_, ...)
			draw_args = {...}
		end,
	}
	local object = {time = 1}
	local slider = {timing = {end_time = 2}}

	local alpha = SliderRenderer.drawBody(object, slider, 0.5, 1, graphics, 3)

	t:eq(alpha, 1)
	t:tdeq(draw_args, {3, 1, 0, 1})
	t:eq(SliderRenderer.getSnakeEnd(object, 0, 1), 0)
	t:eq(SliderRenderer.getSnakeEnd(object, 0.5, 1), 1)
	t:eq(SliderRenderer.getSnakeEnd(object, 0.25, 1), 0.75)
end

---@param t testing.T
function test.fades_slider_body_after_its_end(t)
	local draw_count = 0
	local graphics = {draw = function() draw_count = draw_count + 1 end}
	local object = {time = 1}
	local slider = {timing = {end_time = 2}}
	local alpha = SliderRenderer.drawBody(object, slider, 2.12, 1, graphics, 1)
	t:aeq(alpha, 0.5, 1e-9)
	t:eq(draw_count, 1)
	alpha = SliderRenderer.drawBody(object, slider, 2.24, 1, graphics, 1)
	t:eq(alpha, 0)
	t:eq(draw_count, 1)
end

---@param t testing.T
function test.slider_overlay_renderer_draws_head_ticks_and_ball(t)
	local calls = {}
	local previous_love = love
	love = {graphics = {
		circle = function(mode, x, y, radius)
			table.insert(calls, {mode, x, y, radius})
		end,
		setColor = function() end,
		setLineWidth = function() end,
	}}

	local requested_positions = {}
	local slider = {
		path = {
			points = {{10, 20}, {30, 40}},
			position = function(_, progress)
				table.insert(requested_positions, progress)
				return progress * 100, progress * 200
			end,
		},
		timing = {
			checkpoints = {
				{time = 1.6, progress = 0.25, kind = "tick"},
				{time = 2, progress = 0.5, kind = "repeat"},
				{time = 2.5, progress = 1, kind = "tick"},
			},
			start_time = 0,
			end_time = 3,
			progress = function(_, time) return time / 3 end,
		},
	}

	SliderOverlayRenderer.drawHead({time = 0, x = 10, y = 20}, 10, 0.5, 1)
	SliderOverlayRenderer.drawBodyOverlays(slider, 10, 1.5, 1, 0.3)

	love = previous_love
	t:eq(#calls, 7)
	t:tdeq(calls[1], {"fill", 10, 20, 10})
	t:tdeq(calls[2], {"line", 10, 20, 9})
	t:tdeq(calls[3], {"fill", 25, 50, 4})
	t:tdeq(calls[4], {"line", 30, 60, 6})
	t:tdeq(calls[5], {"line", 50, 100, 10})
	t:tdeq(calls[6], {"fill", 50, 100, 6})
	t:tdeq(calls[7], {"line", 50, 100, 24})
	t:tdeq(requested_positions, {0.25, 0.3, 0.5})
end

return test
