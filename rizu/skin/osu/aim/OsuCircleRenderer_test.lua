local OsuCircleRenderer = require("rizu.skin.osu.aim.OsuCircleRenderer")

local test = {}

---@param t testing.T
function test.draws_loaded_circle_and_approach_sprites_centered_at_hit_position(t)
	local previous_love = love
	---@type table[]
	local draws = {}
	local image = function(width, height)
		return {
			getWidth = function() return width end,
			getHeight = function() return height end,
			getDimensions = function() return width, height end,
		}
	end
	local fake_love = {
		graphics = {
			setColor = function() end,
			draw = function(...)
				draws[#draws + 1] = {...}
			end,
			circle = function() error("loaded osu! sprites should replace primitive circles") end,
		},
	}
	rawset(_G, "love", fake_love)

	local sprites = {
		hitcircle = {image = image(256, 256), density = 0.5},
		hitcircleoverlay = {image = image(256, 256), density = 0.5},
		approachcircle = {image = image(252, 256), density = 0.5},
	}
	---@type chart.osu.AimObject
	local object = {time = 1.2, x = 30, y = 40, kind = "circle", sounds = {}}
	OsuCircleRenderer.draw(object, 20, 0.2, 1.2, sprites)

	rawset(_G, "love", previous_love)
	t:eq(#draws, 3)
	t:eq(draws[1][1], sprites.approachcircle.image)
	t:eq(draws[1][2], 30)
	t:eq(draws[1][3], 40)
	t:eq(draws[1][4], 0)
	t:aeq(draws[1][5], 0.546875, 1e-9)
	t:aeq(draws[1][6], 0.546875, 1e-9)
	t:eq(draws[1][7], 126)
	t:eq(draws[1][8], 128)
	t:eq(draws[2][1], sprites.hitcircle.image)
	t:eq(draws[2][5], 0.15625)
	t:eq(draws[2][7], 128)
	t:eq(draws[2][8], 128)
	t:eq(draws[3][1], sprites.hitcircleoverlay.image)
end

return test
