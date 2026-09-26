local OsuSliderOverlayRenderer = require("rizu.skin.osu.aim.OsuSliderOverlayRenderer")

local test = {}

---@param t testing.T
function test.ignores_transparent_placeholder_repeat_assets(t)
	local previous_love = love
	local draws = {}
	local function image(width, height)
		return {
			getWidth = function() return width end,
			getHeight = function() return height end,
			getDimensions = function() return width, height end,
		}
	end
	love = {graphics = {
		setColor = function() end,
		setLineWidth = function() end,
		circle = function() end,
		draw = function(sprite, x, y, rotation, sx, sy)
			draws[#draws + 1] = {sprite = sprite, x = x, y = y, sx = sx, sy = sy}
		end,
	}}

	local sprites = {
		hitcircle = {image = image(128, 128), density = 1},
		hitcircleoverlay = {image = image(128, 128), density = 1},
		sliderscorepoint = {image = image(1, 1), density = 1},
		sliderendcircle = {image = image(1, 1), density = 1},
		sliderendcircleoverlay = {image = image(1, 1), density = 1},
		reversearrow = {image = image(128, 128), density = 1},
	}
	local slider = {
		path = {position = function(_, progress) return progress * 100, progress * 100 end},
		timing = {
			checkpoints = {
				{time = 1.5, progress = 0.25, kind = "tick"},
				{time = 2, progress = 1, kind = "repeat"},
			},
			start_time = 0,
			end_time = 4,
			spans = 1,
			span_duration = 4,
			velocity = 150,
			progress = function() return 0.5 end,
		},
	}

	OsuSliderOverlayRenderer.drawBodyOverlays(slider, 10, 1, 1, 1, sprites)
	love = previous_love

	t:eq(#draws, 3)
	t:eq(draws[1].sprite:getWidth(), sprites.hitcircle.image:getWidth())
	t:eq(draws[2].sprite:getWidth(), sprites.hitcircleoverlay.image:getWidth())
	t:eq(draws[3].sprite:getWidth(), sprites.reversearrow.image:getWidth())
	for _, draw in ipairs(draws) do
		t:assert(draw.sx < 1 and draw.sy < 1, "osu! overlay sprite scale unexpectedly enlarged")
	end
end

return test
