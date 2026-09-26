local OsuCircleRenderer = require("rizu.skin.osu.aim.OsuCircleRenderer")
local OsuSliderBallRenderer = require("rizu.skin.osu.aim.OsuSliderBallRenderer")
local SpriteRenderer = require("rizu.skin.osu.aim.OsuSpriteRenderer")

---@class rizu.skin.osu.aim.OsuSliderOverlayRenderer
local OsuSliderOverlayRenderer = {}

---@param object chart.osu.AimObject
---@param radius number
---@param time number
---@param preempt number
---@param sprites rizu.skin.osu.aim.OsuSkinGraphics.Sprites?
function OsuSliderOverlayRenderer.drawHead(object, radius, time, preempt, sprites)
	OsuCircleRenderer.draw(object, radius, time, preempt, sprites, true)
end

---@param slider rizu.aim.Slider
---@param radius number
---@param time number
---@param alpha number
---@param snake_end number
---@param sprites rizu.skin.osu.aim.OsuSkinGraphics.Sprites?
---@param framerate number?
function OsuSliderOverlayRenderer.drawBodyOverlays(slider, radius, time, alpha, snake_end, sprites, framerate)
	if alpha <= 0 then return end
	love.graphics.setLineWidth(2)
	love.graphics.setColor(0.85, 0.95, 1, alpha)
	snake_end = math.min(1, math.max(0, snake_end))
	for _, checkpoint in ipairs(slider.timing.checkpoints) do
		if checkpoint.time >= time then
			if checkpoint.kind == "tick" and checkpoint.progress <= snake_end then
				local x, y = slider.path:position(checkpoint.progress)
				local scorepoint = sprites and sprites.sliderscorepoint
				local scorepoint_width = SpriteRenderer.getWidth(scorepoint)
				if scorepoint_width > 0 then
					local size = math.min(radius * 0.5, scorepoint_width)
					SpriteRenderer.draw(scorepoint, x, y, size, alpha)
				else
					love.graphics.circle("fill", x, y, 4)
				end
			elseif checkpoint.kind == "repeat" then
				-- At each repeat the end circle moves from one endpoint to the other.
				local progress = checkpoint.progress == 0 and 1 - snake_end or snake_end
				local x, y = slider.path:position(progress)
				local repeat_circle = sprites and sprites.sliderendcircle
				local repeat_overlay = sprites and sprites.sliderendcircleoverlay
				if SpriteRenderer.getWidth(repeat_circle) == 0 then
					repeat_circle = sprites and sprites.hitcircle
				end
				if SpriteRenderer.getWidth(repeat_overlay) == 0
					and SpriteRenderer.getWidth(sprites and sprites.sliderendcircle) == 0
				then
					repeat_overlay = sprites and sprites.hitcircleoverlay
				end
				local repeat_circle_width = SpriteRenderer.getWidth(repeat_circle)
				local repeat_overlay_width = SpriteRenderer.getWidth(repeat_overlay)
				if repeat_circle_width > 0 then
					SpriteRenderer.draw(repeat_circle, x, y, radius * 2, alpha)
				end
				if repeat_overlay_width > 0 then
					SpriteRenderer.draw(repeat_overlay, x, y, radius * 2, alpha)
				elseif repeat_circle_width == 0 then
					love.graphics.setLineWidth(2)
					love.graphics.setColor(0.85, 0.95, 1, alpha)
					love.graphics.circle("line", x, y, radius - 1)
				end
				local reverse_arrow = sprites and sprites.reversearrow
				if SpriteRenderer.getWidth(reverse_arrow) > 0 then
					local previous_progress = checkpoint.progress == 0 and 1 or 0
					local previous_x, previous_y = slider.path:position(previous_progress)
					local rotation = math.atan2(y - previous_y, x - previous_x) + math.pi
					SpriteRenderer.draw(reverse_arrow, x, y, radius * 1.2, alpha, rotation)
				else
					love.graphics.circle("line", x, y, radius * 0.6)
				end
			end
		end
	end

	OsuSliderBallRenderer.draw(slider, radius, time, alpha, snake_end, sprites, framerate)
end

return OsuSliderOverlayRenderer
