local View = require("rizu.skin.View")

local lg = love.graphics

---@class rizu.skin.views.BgaView.Config
---@field brightness number? BGA brightness from 0 to 1. Defaults to 1.
---@field visible boolean? Whether this view is drawn.
---@field anchor rizu.skin.ViewAnchor? Anchor point in the parent viewport.
---@field origin rizu.skin.ViewAnchor? Point on this view aligned to its anchor.
---@field x number? Horizontal offset from the anchor.
---@field y number? Vertical offset from the anchor.
---@field width number? View width in parent coordinate units. If omitted, fills the parent viewport width.
---@field height number? View height in parent coordinate units. If omitted, fills the parent viewport height.
---@field scale_mode "cover"|"height"? Defaults to cover, or height when only height is specified.

---@class rizu.skin.views.BgaView : rizu.skin.View
---@operator call: rizu.skin.views.BgaView
---@field game sphere.GameController
---@field brightness number?
---@field scale_mode "cover"|"height"
local BgaView = View + {}

---@param game sphere.GameController
---@param config rizu.skin.views.BgaView.Config?
function BgaView:new(game, config)
	assert(game, "BGA view requires a game")
	config = config or {}
	assert(type(config) == "table", "BGA view config must be a table")

	View.new(self, {
		anchor = config.anchor or "center",
		origin = config.origin or "center",
		x = config.x,
		y = config.y,
		width = config.width or 0,
		height = config.height or 0,
		visible = config.visible,
	})
	self.game = game
	self.brightness = config.brightness
	self.scale_mode = config.scale_mode or (config.height and not config.width and "height" or "cover")
	assert(self.scale_mode == "cover" or self.scale_mode == "height", "invalid BGA scale mode")
end

---@return number
function BgaView:getBrightness()
	local brightness = self.brightness
	if type(brightness) ~= "number" or brightness ~= brightness
		or brightness == math.huge or brightness == -math.huge then
		brightness = 1
	end
	return math.max(0, math.min(1, brightness))
end

---@param bga_event rizu.sprite.BgaEvent
---@param time number
---@param bga_engine rizu.sprite.BgaEngine
---@param width number
---@param height number
function BgaView:drawEvent(bga_event, time, bga_engine, width, height)
	---@type love.Drawable?
	local drawable
	if bga_event.type == "VideoNote" then
		local video = bga_engine.video_engine:get(bga_event.name)
		if video then
			video:play(time - bga_event.time)
			drawable = video.image
		end
	else
		drawable = bga_engine.sprite_engine:get(bga_event.name)
	end
	if not drawable then return end

	local drawable_width, drawable_height = drawable:getDimensions()
	if drawable_width <= 0 or drawable_height <= 0 then return end
	local scale = height / drawable_height
	if self.scale_mode == "cover" then
		scale = math.max(width / drawable_width, scale)
	end
	local x = (width - drawable_width * scale) * 0.5
	local y = (height - drawable_height * scale) * 0.5
	lg.draw(drawable, x, y, 0, scale, scale)
end

---@param width number
---@param height number
function BgaView:drawViewport(width, height)
	if width <= 0 or height <= 0 then return end
	local rhythm_engine = self.game.rhythm_engine
	local bga_engine = rhythm_engine and rhythm_engine.bga_engine
	if not bga_engine then return end

	local brightness = self:getBrightness()
	lg.setColor(brightness, brightness, brightness, 1)
	local time = rhythm_engine.visual_info:getTime()
	for _, bga_event in ipairs(bga_engine.active_notes) do
		self:drawEvent(bga_event, time, bga_engine, width, height)
	end
end

function BgaView:draw()
	self:drawViewport(self.width, self.height)
end

-- Missing dimensions inherit the viewport independently. Height-only BGAs
-- preserve each drawable's aspect ratio rather than covering a fixed rectangle.
---@param width number Parent viewport width in drawable pixels.
---@param height number Parent viewport height in drawable pixels.
---@param parent_transform love.Transform?
function BgaView:drawAtAnchors(width, height, parent_transform)
	if not self.visible or width <= 0 or height <= 0 then return end

	local draw_width = self.width > 0 and self.width or width
	local draw_height = self.height > 0 and self.height or height
	---@type love.Transform
	local transform = self._world_transform or love.math.newTransform()
	self._world_transform = transform
	transform:reset()
	if parent_transform then transform:apply(parent_transform) end
	local anchor, origin = View.anchors[self.anchor], View.anchors[self.origin]
	local origin_x, origin_y = draw_width * origin[1], draw_height * origin[2]
	transform:translate(width * anchor[1] + self.x, height * anchor[2] + self.y)
	transform:apply(self.transform)
	transform:translate(-origin_x, -origin_y)

	local x1, y1 = transform:transformPoint(0, 0)
	local x2, y2 = transform:transformPoint(draw_width, draw_height)
	local left, right = math.min(x1, x2), math.max(x1, x2)
	local top, bottom = math.min(y1, y2), math.max(y1, y2)
	if right <= left or bottom <= top then return end

	lg.push("all")
	lg.setScissor(left, top, right - left, bottom - top)
	lg.replaceTransform(transform)
	self:drawViewport(draw_width, draw_height)
	lg.setScissor()
	lg.pop()
end

return BgaView
