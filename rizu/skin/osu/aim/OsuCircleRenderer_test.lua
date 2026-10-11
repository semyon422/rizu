local OsuCircleRenderer = require("rizu.skin.osu.aim.OsuCircleRenderer")

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
---@return table[]
local function capture(draw)
	local previous_love = love
	---@type table[]
	local draws = {}
	local color = {1, 1, 1, 1}
	rawset(_G, "love", {
		graphics = {
			setColor = function(...) color = {...} end,
			draw = function(...)
				draws[#draws + 1] = {alpha = color[4], ...}
			end,
			circle = function() error("loaded osu! sprites should replace primitive circles") end,
		},
	})
	local ok, err = pcall(draw)
	rawset(_G, "love", previous_love)
	assert(ok, err)
	return draws
end

---@param t testing.T
function test.draws_loaded_circle_and_approach_sprites_centered_at_hit_position(t)
	local sprites = {
		hitcircle = image(128, 128),
		hitcircleoverlay = image(128, 128),
		approachcircle = image(126, 128),
	}
	local object = {time = 1.2, x = 30, y = 40, kind = "circle", sounds = {}, combo_number = 1}
	local draws = capture(function() OsuCircleRenderer.draw(object, 20, 0.2, 1.2, sprites) end)

	t:eq(#draws, 3)
	t:eq(draws[1][1], sprites.approachcircle)
	t:eq(draws[1][2], 30)
	t:eq(draws[1][3], 40)
	t:eq(draws[1][4], 0)
	t:aeq(draws[1][5], 1.09375, 1e-9)
	t:aeq(draws[1][6], 1.09375, 1e-9)
	t:eq(draws[1][7], 63)
	t:eq(draws[1][8], 64)
	t:eq(draws[2][1], sprites.hitcircle)
	t:eq(draws[2][5], 0.3125)
	t:eq(draws[2][7], 64)
	t:eq(draws[2][8], 64)
	t:eq(draws[3][1], sprites.hitcircleoverlay)
end

---@param t testing.T
function test.draws_combo_number_centered_between_circle_and_overlay(t)
	local sprites = {
		hitcircle = image(128, 128),
		hitcircleoverlay = image(128, 128),
		digits = {[1] = image(20, 50), [2] = image(30, 50)},
		digit_overlap = -2,
	}
	local object = {time = 1, x = 100, y = 100, kind = "circle", sounds = {}, combo_number = 12}
	-- A 64 radius circle is osu!'s native texture size, so glyphs scale by 0.8.
	local draws = capture(function() OsuCircleRenderer.draw(object, 64, 1, 1.2, sprites) end)

	t:eq(#draws, 4)
	t:eq(draws[1][1], sprites.hitcircle)
	t:eq(draws[2][1], sprites.digits[1])
	t:aeq(draws[2][2], 100 - 52 * 0.8 / 2, 1e-9)
	t:aeq(draws[2][3], 100 - 50 * 0.8 / 2, 1e-9)
	t:aeq(draws[2][5], 0.8, 1e-9)
	t:eq(draws[3][1], sprites.digits[2])
	t:aeq(draws[3][2], draws[2][2] + 22 * 0.8, 1e-9)
	t:eq(draws[4][1], sprites.hitcircleoverlay)
end

---@param t testing.T
function test.hit_circle_expands_and_fades_without_number_or_approach_circle(t)
	local sprites = {
		hitcircle = image(128, 128),
		hitcircleoverlay = image(128, 128),
		approachcircle = image(128, 128),
		digits = {[1] = image(20, 50)},
		digit_overlap = -2,
	}
	local object = {time = 1, x = 0, y = 0, kind = "circle", sounds = {}, combo_number = 1}
	local draws = capture(function()
		OsuCircleRenderer.draw(object, 64, 0.95 + 0.12, 1.2, sprites, false, "hit", 0.95)
	end)
	t:eq(#draws, 2)
	t:eq(draws[1][1], sprites.hitcircle)
	t:aeq(draws[1][5], 1.3, 1e-9)
	t:aeq(draws[1].alpha, 0.5, 1e-9)

	t:eq(#capture(function() OsuCircleRenderer.draw(object, 64, 2, 1.2, sprites, false, "hit", 0.95) end), 0)
	-- A missed circle keeps its number while it fades.
	t:eq(#capture(function() OsuCircleRenderer.draw(object, 64, 1.23, 1.2, sprites, false, "miss", 1.2) end), 3)
end

return test
