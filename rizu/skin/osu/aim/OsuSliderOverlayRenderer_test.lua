local OsuSliderOverlayRenderer = require("rizu.skin.osu.aim.OsuSliderOverlayRenderer")

local test = {}

---@param width number
---@param height number
local function image(width, height)
	return {
		getWidth = function() return width end,
		getHeight = function() return height end,
		getDimensions = function() return width, height end,
	}
end

---@param draw fun()
---@return {sprite: table, x: number, y: number, rotation: number, sx: number}[]
local function capture(draw)
	local previous_love = love
	local draws = {}
	rawset(_G, "love", {graphics = {
		setColor = function() end,
		setLineWidth = function() end,
		circle = function() end,
		draw = function(sprite, x, y, rotation, sx)
			draws[#draws + 1] = {sprite = sprite, x = x, y = y, rotation = rotation, sx = sx}
		end,
	}})
	local ok, err = pcall(draw)
	rawset(_G, "love", previous_love)
	assert(ok, err)
	return draws
end

---@param spans integer
local function slider(spans)
	return {
		path = {position = function(_, progress) return progress * 100, 0 end},
		timing = {
			checkpoints = {},
			start_time = 0,
			end_time = spans,
			spans = spans,
			span_duration = 1,
			progress = function() return 0.5 end,
		},
	}
end

---@param t testing.T
function test.end_circle_sits_where_the_final_span_finishes_and_ignores_placeholders(t)
	local sprites = {
		hitcircle = image(128, 128),
		hitcircleoverlay = image(128, 128),
		sliderendcircle = image(1, 1),
		sliderendcircleoverlay = image(1, 1),
	}
	local draws = capture(function() OsuSliderOverlayRenderer.drawEndCircle(slider(2), 10, 1, 1, sprites) end)
	t:eq(#draws, 2)
	t:eq(draws[1].sprite, sprites.hitcircle)
	t:eq(draws[2].sprite, sprites.hitcircleoverlay)
	t:eq(draws[1].x, 0)

	draws = capture(function() OsuSliderOverlayRenderer.drawEndCircle(slider(3), 10, 1, 1, sprites) end)
	t:eq(draws[1].x, 100)
	-- While the body snakes in, the far end circle rides its leading edge.
	draws = capture(function() OsuSliderOverlayRenderer.drawEndCircle(slider(3), 10, 1, 0.5, sprites) end)
	t:eq(draws[1].x, 50)
	t:eq(#capture(function() OsuSliderOverlayRenderer.drawEndCircle(slider(3), 10, 0, 1, sprites) end), 0)
end

---@param t testing.T
function test.only_the_current_span_shows_a_reverse_arrow_pointing_back_along_the_path(t)
	local sprites = {reversearrow = image(128, 128)}
	local three_spans = slider(3)
	local function arrows(time)
		return capture(function()
			OsuSliderOverlayRenderer.drawReverseArrow(three_spans, 64, time, 1, 1.2, sprites)
		end)
	end

	-- The body is still snaking in.
	t:eq(#arrows(-1), 0)
	local first = arrows(-0.2)
	t:eq(#first, 1)
	t:eq(first[1].x, 100)
	t:aeq(math.abs(first[1].rotation), math.pi, 1e-6)
	local second = arrows(1.5)
	t:eq(#second, 1)
	t:eq(second[1].x, 0)
	t:aeq(second[1].rotation, 0, 1e-6)
	-- The final span has no repeat left.
	t:eq(#arrows(2.5), 0)
	-- Each pulse starts enlarged and settles at the native size.
	t:aeq(arrows(1.6 + 1e-6)[1].sx, 1.3, 1e-4)
	t:aeq(arrows(1.6 - 1e-6)[1].sx, 1, 1e-4)
end

return test
