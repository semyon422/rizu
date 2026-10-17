local BgaView = require("rizu.skin.views.BgaView")
local PlayfieldRenderer = require("rizu.gameplay.views.PlayfieldRenderer")

local test = {}

---@param t testing.T
function test.base_renderer_has_empty_huds(t)
	local renderer = PlayfieldRenderer({})
	t:eq(#renderer.background_hud.children, 0)
	t:eq(#renderer.foreground_hud.children, 0)
end

---@param t testing.T
function test.height_scaling_preserves_varying_aspect_ratios(t)
	local view = BgaView({}, {height = 240})
	t:eq(view.scale_mode, "height")
	local old_draw = love.graphics.draw
	local calls = {}
	love.graphics.draw = function(_, x, y, _, sx, sy)
		calls[#calls + 1] = {x, y, sx, sy}
	end
	local ok, err = pcall(function()
		for _, dimensions in ipairs({{100, 100}, {400, 100}, {100, 400}}) do
			local drawable = {getDimensions = function() return unpack(dimensions) end}
			local engine = {sprite_engine = {get = function() return drawable end}}
			view:drawEvent({type = "ImageNote", name = "test"}, 0, engine, 640, 240)
		end
	end)
	love.graphics.draw = old_draw
	if not ok then error(err) end
	t:tdeq(calls[1], {200, 0, 2.4, 2.4})
	t:tdeq(calls[2], {-160, 0, 2.4, 2.4})
	t:tdeq(calls[3], {290, 0, 0.6, 0.6})
end

---@param t testing.T
function test.height_only_view_uses_anchors_and_parent_transform(t)
	local view = BgaView({}, {height = 240, x = 10, y = 20})
	local dimensions
	view.drawViewport = function(_, width, height) dimensions = {width, height} end
	local parent = love.math.newTransform(100, 50)
	view:drawAtAnchors(640, 480, parent)
	t:tdeq(dimensions, {640, 240})
	local x, y = view._world_transform:transformPoint(0, 0)
	t:eq(x, 110)
	t:eq(y, 190)
end

return test
