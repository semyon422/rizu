local SpriteBatch = require("rizu.skin.SpriteBatch")
local TextureImage = require("rizu.skin.TextureImage")

local test = {}

local function with_graphics(callback)
	local lg = love.graphics
	local saved = {}
	for _, name in ipairs({"newSpriteBatch", "draw", "getColor", "setColor",
		"getBlendMode", "setBlendMode"}) do saved[name] = lg[name] end
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
	local ok, err = xpcall(function() callback(draws) end, debug.traceback)
	for name in pairs(saved) do lg[name] = saved[name] end
	-- FakeLove does not define getBlendMode; restore absent functions too.
	lg.getBlendMode = saved.getBlendMode
	if not ok then error(err) end
end

function test.nested_scopes_preserve_order_and_outer_ownership(t)
	with_graphics(function(draws)
		local batch = SpriteBatch()
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
		TextureImage.drawDirect(frame, 10, 15, 0.5, 3, -4, 5, 6)
		t:tdeq(draws[1].args, {frame.texture, frame.quad, 10, 15, 0.5, 1.5, -2, 10, 12})
	end)
end

return test
