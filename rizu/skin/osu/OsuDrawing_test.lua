local OsuSpriteBatch = require("rizu.skin.osu.OsuSpriteBatch")
local OsuImage = require("rizu.skin.osu.OsuImage")
local ProgressView = require("rizu.skin.osu.mania.views.OsuManiaProgressView")
local HitMeterView = require("rizu.skin.osu.mania.views.OsuManiaHitMeterView")

local test = {}

local function with_graphics(callback)
	local lg = love.graphics
	local saved = {}
	for _, name in ipairs({"newSpriteBatch", "draw", "getColor", "setColor",
		"getBlendMode", "setBlendMode", "circle", "arc"}) do saved[name] = lg[name] end
	local draws, color = {}, {1, 1, 1, 1}
	local mode, alpha = "alpha", "alphamultiply"
	lg.newSpriteBatch = function(texture)
		local batch = {texture = texture, count = 0}
		function batch:getCount() return self.count end
		function batch:clear() self.count = 0 end
		function batch:setColor() end
		function batch:add() self.count = self.count + 1 end
		function batch:release() end
		return batch
	end
	lg.getColor = function() return unpack(color) end
	lg.setColor = function(...) color = {...} end
	lg.getBlendMode = function() return mode, alpha end
	lg.setBlendMode = function(m, a) mode, alpha = m, a end
	lg.draw = function(...) draws[#draws + 1] = {args = {...}, mode = mode, alpha = alpha} end
	lg.circle, lg.arc = function() end, function() end
	local ok, err = xpcall(function() callback(draws) end, debug.traceback)
	for name in pairs(saved) do lg[name] = saved[name] end
	-- FakeLove does not define getBlendMode; restore absent functions too.
	lg.getBlendMode = saved.getBlendMode
	if not ok then error(err) end
end

function test.nested_scopes_preserve_order_and_outer_ownership(t)
	with_graphics(function(draws)
		local batch = OsuSpriteBatch()
		local a, b, quad = {}, {}, {}
		batch:loadPage(a)
		batch:loadPage(b)
		batch:begin()
		batch:add(a, quad, 0, 0, 0, 1, 1, 0, 0)
		batch:begin()
		batch:add(a, quad, 1, 0, 0, 1, 1, 0, 0)
		batch:finish()
		t:eq(#draws, 0)
		batch:add(b, quad, 2, 0, 0, 1, 1, 0, 0)
		t:eq(#draws, 1)
		t:eq(draws[1].args[1], batch.pages[a])
		batch:finish()
		t:eq(#draws, 2)
		t:eq(draws[2].args[1], batch.pages[b])
		t:eq(pcall(batch.finish, batch), false)
	end)
end

function test.direct_atlas_draw_bypasses_batch_and_scales_density_once(t)
	with_graphics(function(draws)
		local frame = {texture = {}, quad = {}, width = 20, height = 30, density = 2,
			batch = {add = function() error("effect must not enqueue sprites") end}}
		OsuImage.drawDirect(frame, 10, 15, 0.5, 3, -4, 5, 6)
		t:tdeq(draws[1].args, {frame.texture, frame.quad, 10, 15, 0.5, 1.5, -2, 10, 12})
	end)
end

function test.progress_effect_flushes_before_blend_change_and_restores_it(t)
	with_graphics(function(draws)
		local batch = OsuSpriteBatch()
		local texture, quad = {}, {}
		batch:loadPage(texture)
		local graphics = {batch = batch, getFrames = function()
			return {{texture = texture, quad = quad, width = 20, height = 20, density = 2,
				batch = {add = function() error("progress effect must draw directly") end}}}
		end}
		local view = ProgressView(graphics)
		view:load({})
		batch:begin()
		batch:add(texture, quad, 0, 0, 0, 1, 1, 0, 0)
		view:draw()
		t:eq(#draws, 2)
		t:eq(draws[1].args[1], batch.pages[texture])
		t:eq(draws[1].mode, "alpha")
		t:eq(draws[2].args[1], texture)
		t:eq(draws[2].mode, "add")
		t:eq(love.graphics.getBlendMode(), "alpha")
		batch:add(texture, quad, 0, 0, 0, 1, 1, 0, 0)
		batch:finish()
		t:eq(draws[3].mode, "alpha")
	end)
end

function test.views_acquire_images_only_on_load_and_replace_them_on_reload(t)
	with_graphics(function()
		local calls = 0
		local image = {getDimensions = function() return 20, 20 end}
		local graphics = {getFrames = function(_, _, _, group)
			t:eq(group, "standalone")
			calls = calls + 1
			return {image}
		end}
		local progress, meter = ProgressView(graphics), HitMeterView(graphics)
		t:eq(calls, 0)
		progress:load({})
		meter:load({})
		for _ = 1, 3 do progress:draw() end
		t:eq(calls, 2)
		progress:unload()
		meter:unload()
		t:eq(progress.progress_image, nil)
		t:eq(meter.arrow_image, nil)
		image = {getDimensions = function() return 40, 40 end}
		progress:load({})
		meter:load({})
		t:eq(calls, 4)
		t:eq(progress.progress_image, image)
		t:eq(meter.arrow_image, image)
	end)
end

return test
