local HitLighting = require("rizu.skin.easy_lua.HitLighting")

local test = {}

---@param t testing.T
function test.trigger_restarts_the_full_width_collapse_animation(t)
	local old_draw, old_set_color = love.graphics.draw, love.graphics.setColor
	local draw_args ---@type any[]?
	local color_args ---@type number[]?
	rawset(love.graphics, "draw", function(image, ...)
		draw_args = {image, ...}
	end)
	rawset(love.graphics, "setColor", function(...)
		color_args = {...}
	end)
	local image = {
		getWidth = function() return 40 end,
		getHeight = function() return 480 end,
		getDimensions = function() return 40, 480 end,
	}
	local lighting = HitLighting({image = image, width = 40, color = {0.2, 0.4, 0.6, 0.15}, duration = 1})
	local ok, err = pcall(function()
		lighting:draw(100, 420)
		t:eq(draw_args, nil)
		lighting:trigger()
		lighting:draw(100, 420)
		local first_draw = assert(draw_args)
		t:eq(first_draw[2], 100)
		t:eq(first_draw[3], 420)
		t:eq(first_draw[5], 1)
		t:tdeq(color_args, {0.2, 0.4, 0.6, 0.15})
		lighting:update(0.5)
		lighting:draw(100, 420)
		t:eq(assert(draw_args)[5], 1 / 4)
		lighting:trigger()
		t:eq(lighting.elapsed, 0)
		lighting:draw(100, 420)
		t:eq(assert(draw_args)[5], 1)
		lighting:update(1)
		t:eq(lighting.active, false)
	end)
	rawset(love.graphics, "draw", old_draw)
	rawset(love.graphics, "setColor", old_set_color)
	if not ok then error(err) end
end

return test
