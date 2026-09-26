local SpriteRenderer = require("rizu.skin.osu.aim.OsuSpriteRenderer")

local test = {}

---@param t testing.T
function test.does_not_draw_single_pixel_transparent_placeholders(t)
	local previous_love = love
	local draw_count = 0
	rawset(_G, "love", {graphics = {
		setColor = function() end,
		draw = function() draw_count = draw_count + 1 end,
	}})
	local sprite = {image = {
		getWidth = function() return 1 end,
		getHeight = function() return 1 end,
		getDimensions = function() return 1, 1 end,
	}, density = 1}

	SpriteRenderer.draw(sprite, 100, 100, 200, 1)

	rawset(_G, "love", previous_love)
	t:eq(draw_count, 0)
end

return test
