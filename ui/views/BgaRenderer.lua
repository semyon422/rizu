local class = require("class")

local lg = love.graphics

---@class ui.views.BgaRenderer
---@operator call: ui.views.BgaRenderer
local BgaRenderer = class()

---@param bga_event rizu.sprite.BgaEvent
---@param time number
---@param bga_engine rizu.sprite.BgaEngine|rizu.preview.BgaPreviewPlayer
---@param width number
---@param height number
function BgaRenderer:drawEvent(bga_event, time, bga_engine, width, height)
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

	if not drawable then
		return
	end

	local drawable_width, drawable_height = drawable:getDimensions()
	local scale = math.max(width / drawable_width, height / drawable_height)
	local x = (width - drawable_width * scale) * 0.5
	local y = (height - drawable_height * scale) * 0.5
	lg.draw(drawable, x, y, 0, scale, scale)
end

---@param bga_engine rizu.sprite.BgaEngine|rizu.preview.BgaPreviewPlayer?
---@param time number
---@param width number
---@param height number
function BgaRenderer:draw(bga_engine, time, width, height)
	if not bga_engine then
		return
	end

	for _, bga_event in ipairs(bga_engine.active_notes) do
		self:drawEvent(bga_event, time, bga_engine, width, height)
	end
end

return BgaRenderer
