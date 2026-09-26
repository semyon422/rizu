local OsuSliderBallRenderer = require("rizu.skin.osu.aim.OsuSliderBallRenderer")

local test = {}

---@param t testing.T
function test.draws_ball_frame_and_follow_circle_along_active_slider(t)
	local previous_love = love
	local draws = {}
	local function image(size)
		return {
			getWidth = function() return size end,
			getHeight = function() return size end,
			getDimensions = function() return size, size end,
		}
	end
	local frames = {
		{image = image(128), density = 1},
		{image = image(128), density = 1},
		{image = image(128), density = 1},
	}
	local follow = {image = image(200), density = 1}
	love = {graphics = {
		setColor = function() end,
		draw = function(sprite, x, y, rotation, sx, sy)
			draws[#draws + 1] = {sprite, x, y, rotation, sx, sy}
		end,
	}}

	local slider = {
		path = {position = function(_, progress) return 20 + progress * 100, 30 + progress * 80 end},
		timing = {
			start_time = 1,
			end_time = 3,
			spans = 2,
			span_duration = 1,
			progress = function(_, time) return time < 2 and time - 1 or 3 - time end,
		},
	}

	OsuSliderBallRenderer.draw(slider, 10, 1.5, 0.75, 0.5,
		{sliderb = frames, sliderfollowcircle = follow}, 2)
	love = previous_love

	t:eq(#draws, 2)
	t:eq(draws[1][1]:getWidth(), follow.image:getWidth())
	t:aeq(draws[1][2], 70, 1e-9)
	t:aeq(draws[1][3], 70, 1e-9)
	t:aeq(draws[1][5], 0.24, 1e-9)
	t:eq(draws[2][1]:getWidth(), frames[1].image:getWidth())
	t:aeq(draws[2][2], 70, 1e-9)
	t:aeq(draws[2][3], 70, 1e-9)
	t:aeq(draws[2][4], math.atan2(80, 100), 1e-6)
	t:aeq(draws[2][5], 0.15625, 1e-9)
end

---@param t testing.T
function test.does_not_draw_slider_ball_before_snake_reaches_it(t)
	local previous_love = love
	local draw_count = 0
	love = {graphics = {setColor = function() end, draw = function() draw_count = draw_count + 1 end}}
	local image = {image = {
		getWidth = function() return 100 end,
		getHeight = function() return 100 end,
		getDimensions = function() return 100, 100 end,
	}, density = 1}
	local slider = {
		path = {position = function() return 0, 0 end},
		timing = {start_time = 0, end_time = 2, progress = function() return 0.8 end},
	}

	OsuSliderBallRenderer.draw(slider, 10, 1, 1, 0.5, {sliderb = {image}, sliderfollowcircle = image})
	love = previous_love
	t:eq(draw_count, 0)
end

return test
