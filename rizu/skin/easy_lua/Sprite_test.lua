local Sprite = require("rizu.skin.easy_lua.Sprite")

local test = {}

---@param t testing.T
function test.draws_configured_sprite_with_native_geometry_and_centered_origin(t)
	local graphics = love.graphics
	local old_draw, old_set_color = graphics.draw, graphics.setColor
	local draw_args ---@type any[]?
	local color_args ---@type number[]?
	rawset(graphics, "draw", function(image, ...)
		draw_args = {image, ...}
	end)
	rawset(graphics, "setColor", function(...)
		color_args = {...}
	end)
	local image = {getDimensions = function() return 20, 10 end}
	local sprite = Sprite({
		image = image,
		x = 100,
		y = 200,
		offset_x = 3,
		offset_y = -4,
		scale_x = 2,
		scale_y = 0.5,
		rotation = math.pi / 2,
		color = {0.2, 0.4, 0.6, 0.8},
	})
	local ok, err = pcall(function()
		sprite:draw()
		local args = assert(draw_args)
		t:eq(args[1], image)
		t:eq(args[2], 103)
		t:eq(args[3], 196)
		t:eq(args[4], math.pi / 2)
		t:eq(args[5], 2)
		t:eq(args[6], 0.5)
		t:eq(args[7], 10)
		t:eq(args[8], 5)
		t:tdeq(color_args, {0.2, 0.4, 0.6, 0.8})

		draw_args = nil
		sprite:draw(12, 34)
		t:eq(assert(draw_args)[2], 15)
		t:eq(assert(draw_args)[3], 30)
	end)
	rawset(graphics, "draw", old_draw)
	rawset(graphics, "setColor", old_set_color)
	if not ok then error(err) end
end

---@param t testing.T
function test.supports_custom_origin_and_validates_sprite_config(t)
	local image = {getDimensions = function() return 20, 10 end}
	local sprite = Sprite({image = image, origin_x = 0, origin_y = 1, scale_x = 0})
	t:eq(sprite.origin_x, 0)
	t:eq(sprite.origin_y, 1)
	t:eq(sprite.scale_x, 0)
	t:assert(not pcall(function() Sprite({image = image, origin_x = 1.1}) end))
	t:assert(not pcall(function() Sprite({image = image, x = math.huge}) end))
	t:assert(not pcall(function() Sprite({image = image, color = {1, 0, -1}}) end))
	t:assert(not pcall(function() Sprite({}) end))
end

return test
