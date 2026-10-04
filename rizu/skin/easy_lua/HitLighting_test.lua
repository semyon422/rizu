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

---@param t testing.T
function test.fade_animation_keeps_size_and_fades_alpha_from_bottom_anchor(t)
	local old_draw, old_set_color = love.graphics.draw, love.graphics.setColor
	local draw_calls = {} ---@type table[]
	local color_args ---@type number[]?
	rawset(love.graphics, "draw", function(image, ...)
		draw_calls[#draw_calls + 1] = {image, ...}
	end)
	rawset(love.graphics, "setColor", function(...)
		color_args = {...}
	end)
	local image = {getWidth = function() return 64 end, getDimensions = function() return 64, 640 end}
	local lighting = HitLighting({
		image = image,
		width = 28,
		scale_y = 0.75,
		origin_y = 1,
		animation = "fade",
		duration = 1,
		color = {1, 1, 1, 0.2},
	})
	local ok, err = pcall(function()
		lighting:trigger()
		lighting:draw(125, 330)
		local first = draw_calls[#draw_calls]
		t:eq(first[1], image)
		t:eq(first[2], 125)
		t:eq(first[3], 330)
		t:eq(first[5], 28 / 64)
		t:eq(first[6], 0.75)
		t:eq(first[7], 32)
		t:eq(first[8], 640)
		t:tdeq(color_args, {1, 1, 1, 0.2})

		lighting:update(0.25)
		lighting:draw(125, 330)
		local faded = draw_calls[#draw_calls]
		t:eq(faded[5], 28 / 64)
		t:eq(faded[6], 0.75)
		t:eq(math.floor(color_args[4] * 100 + 0.5) / 100, 0.15)

		lighting:trigger()
		t:eq(lighting.elapsed, 0)
		lighting:draw(125, 330)
		t:tdeq(color_args, {1, 1, 1, 0.2})
		lighting:update(1)
		t:eq(lighting.active, false)
		local draw_count = #draw_calls
		lighting:draw(125, 330)
		t:eq(#draw_calls, draw_count)
	end)
	rawset(love.graphics, "draw", old_draw)
	rawset(love.graphics, "setColor", old_set_color)
	if not ok then error(err) end
end

---@param t testing.T
function test.frame_animation_uses_native_width_and_fades_alpha(t)
	local original_draw, original_color = love.graphics.draw, love.graphics.setColor
	local calls = {} ---@type table[]
	local colors = {} ---@type table[]
	rawset(love.graphics, "draw", function(image, ...)
		calls[#calls + 1] = {image, ...}
	end)
	rawset(love.graphics, "setColor", function(...) colors[#colors + 1] = {...} end)
	local first_frame = {getWidth = function() return 80 end, getDimensions = function() return 80, 40 end}
	local second_frame = {getWidth = function() return 100 end, getDimensions = function() return 100, 40 end}
	local lighting = HitLighting({
		frames = {first_frame, second_frame},
		frame_rate = 10,
		animation = "fade",
		duration = 1,
		color = {1, 1, 1, 0.5},
	})
	local ok, err = pcall(function()
		lighting:trigger()
		lighting:draw(100, 200)
		t:eq(calls[#calls][1], first_frame)
		t:eq(calls[#calls][5], 1)
		lighting:update(0.1)
		lighting:draw(100, 200)
		t:eq(calls[#calls][1], second_frame)
		t:eq(calls[#calls][5], 1)
		t:eq(colors[#colors][4], 0.45)
	end)
	rawset(love.graphics, "draw", original_draw)
	rawset(love.graphics, "setColor", original_color)
	if not ok then error(err) end
end

function test.set_held_does_not_affect_a_oneshot_animation(t)
	local image = {getWidth = function() return 40 end, getDimensions = function() return 40, 40 end}
	local lighting = HitLighting({image = image, duration = 1})

	lighting:trigger()
	lighting:update(0.25)
	lighting:setHeld(true)
	t:eq(lighting.elapsed, 0.25)
	t:eq(lighting.active, true)

	lighting:setHeld(false)
	t:eq(lighting.elapsed, 0.25)
	t:eq(lighting.active, true)
end

---@param t testing.T
function test.hold_mode_advances_until_release(t)
	local image = {getWidth = function() return 40 end, getDimensions = function() return 40, 40 end}
	local lighting = HitLighting({image = image, mode = "hold", duration = 1})

	lighting:setHeld(true)
	lighting:update(0.25)
	lighting:setHeld(true)
	t:eq(lighting.elapsed, 0.25)
	t:eq(lighting.active, true)

	lighting:setHeld(false)
	t:eq(lighting.active, true)
	lighting:update(0)
	t:eq(lighting.active, false)
end

---@param t testing.T
function test.rejects_unknown_animation(t)
	local image = {getWidth = function() return 40 end}
	t:assert(not pcall(function()
		HitLighting({image = image, animation = "pulse"})
	end))
end

---@param t testing.T
function test.uses_requested_animation_frames_rate_and_blend_mode(t)
	local old_draw, old_color, old_blend = love.graphics.draw, love.graphics.setColor, love.graphics.setBlendMode
	local draw_calls = {} ---@type table[]
	local colors = {} ---@type table[]
	local blend_calls = {} ---@type table[]
	rawset(love.graphics, "draw", function(image, ...)
		draw_calls[#draw_calls + 1] = {image, ...}
	end)
	rawset(love.graphics, "setColor", function(...) colors[#colors + 1] = {...} end)
	rawset(love.graphics, "setBlendMode", function(...) blend_calls[#blend_calls + 1] = {...} end)
	local function image(name)
		return {
			name = name,
			getWidth = function() return 20 end,
			getDimensions = function() return 20, 30 end,
		}
	end
	local note = {getWidth = function() return 30 end, getDimensions = function() return 30, 20 end}
	local lighting = HitLighting({image = note})
	t:eq(lighting.width, 30)
	t:eq(lighting.fit_width, false)

	local frames = {image("0"), image("1"), image("2")}
	local lighting = HitLighting({
		frames = frames,
		frame_rate = 4,
		width = 40,
		fit_width = false,
		duration = 1,
		animation = "fade",
		blend_mode = {"add", "alphamultiply"},
		color = {1, 1, 1, 0.5},
	})
	local ok, err = pcall(function()
		t:eq(lighting.image, frames[1])
		t:eq(lighting.frame_rate, 4)
		lighting:trigger()
		lighting:draw(100, 200)
		t:eq(draw_calls[#draw_calls][1], frames[1])
		t:eq(draw_calls[#draw_calls][5], 1)
		lighting:update(0.25)
		lighting:draw(100, 200)
		t:eq(draw_calls[#draw_calls][1], frames[2])
		t:eq(draw_calls[#draw_calls][5], 1)
		lighting:update(0.25)
		lighting:draw(100, 200)
		t:eq(draw_calls[#draw_calls][1], frames[3])
		t:eq(draw_calls[#draw_calls][5], 1)
		t:tdeq(blend_calls[#blend_calls], {"add", "alphamultiply"})
		t:tdeq(colors[#colors], {1, 1, 1, 0.25})
		lighting:update(0.5)
		t:eq(lighting.active, false)
	end)
	rawset(love.graphics, "draw", old_draw)
	rawset(love.graphics, "setColor", old_color)
	rawset(love.graphics, "setBlendMode", old_blend)
	if not ok then error(err) end
end

---@param t testing.T
function test.rejects_invalid_frame_and_blend_config(t)
	local image = {getWidth = function() return 40 end, getDimensions = function() return 40, 40 end}
	t:assert(not pcall(function() HitLighting({frames = {}}) end))
	t:assert(not pcall(function() HitLighting({image = image, frames = {image}}) end))
	t:assert(not pcall(function() HitLighting({image = image, frame_rate = 0}) end))
	t:assert(not pcall(function() HitLighting({image = image, blend_mode = {42}}) end))
end

return test
