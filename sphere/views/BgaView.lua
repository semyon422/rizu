local class = require("class")
local gfx_util = require("gfx_util")

---@class sphere.BgaView
---@operator call: sphere.BgaView
---@field game sphere.GameController
local BgaView = class()

---@param bga_event rizu.sprite.BgaEvent
---@param time number
---@param bga_engine rizu.sprite.BgaEngine|rizu.preview.BgaPreviewPlayer
function BgaView:drawNote(bga_event, time, bga_engine)
	local start_dt = time - bga_event.time

	---@type love.Drawable?
	local drawable
	if bga_event.type == "VideoNote" then
		local video = bga_engine.video_engine:get(bga_event.name)
		if video then
			video:play(start_dt)
			drawable = video.image
		end
	else
		drawable = bga_engine.sprite_engine:get(bga_event.name)
	end

	if not drawable then
		return
	end

	local w, h = love.graphics.getDimensions()
	love.graphics.setColor(1, 1, 1, 1)
	gfx_util.drawFrame(drawable, 0, 0, w, h, "out")
end

function BgaView:draw()
	local bga_engine
	local time

	local rhythm_engine = self.game.rhythm_engine
	local is_gameplay_loaded = self.game.gameplayInteractor and self.game.gameplayInteractor.loaded
	if is_gameplay_loaded and rhythm_engine and rhythm_engine.bga_engine and #rhythm_engine.bga_engine.active_notes > 0 then
		bga_engine = rhythm_engine.bga_engine
		time = rhythm_engine.visual_info:getTime()
	elseif self.game.previewModel and self.game.previewModel.bgaPreviewPlayer then
		bga_engine = self.game.previewModel.bgaPreviewPlayer
		time = self.game.previewModel:getTime()
	end

	if not bga_engine then
		return
	end

	love.graphics.origin()

	for _, bga_event in ipairs(bga_engine.active_notes) do
		self:drawNote(bga_event, time, bga_engine)
	end
end

return BgaView

