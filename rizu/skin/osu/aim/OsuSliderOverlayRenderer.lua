local OsuCircleRenderer = require("rizu.skin.osu.aim.OsuCircleRenderer")
local OsuSliderBallRenderer = require("rizu.skin.osu.aim.OsuSliderBallRenderer")
local SpriteRenderer = require("rizu.skin.osu.aim.OsuSpriteRenderer")

---@class rizu.skin.osu.aim.OsuSliderOverlayRenderer
local OsuSliderOverlayRenderer = {}

---@param object chart.osu.AimObject
---@param radius number
---@param time number
---@param preempt number
---@param sprites rizu.skin.osu.aim.OsuAimSprites?
---@param head_state ("hit"|"miss")?
---@param head_time number?
---@param color number[]?
function OsuSliderOverlayRenderer.drawHead(object, radius, time, preempt, sprites, head_state, head_time, color)
	OsuCircleRenderer.draw(object, radius, time, preempt, sprites, true, head_state, head_time, color)
end

---One end circle, where the final span finishes. OsuAimSprites decides whether the skin shows it.
---@param slider rizu.aim.Slider
---@param radius number
---@param alpha number
---@param snake_end number
---@param sprites rizu.skin.osu.aim.OsuAimSprites?
---@param color number[]?
function OsuSliderOverlayRenderer.drawEndCircle(slider, radius, alpha, snake_end, sprites, color)
	if alpha <= 0 or not sprites then return end
	-- An end circle at the far end rides the snaking edge of the body.
	local x, y = slider.path:position(slider.timing.spans % 2 * math.min(1, math.max(0, snake_end)))
	SpriteRenderer.draw(sprites.sliderendcircle, x, y, radius * 2, alpha, 0, color)
	SpriteRenderer.draw(sprites.sliderendcircleoverlay, x, y,
		SpriteRenderer.getOverlayWidth(sprites.sliderendcircleoverlay, radius * 2), alpha)
end

local reverse_arrow_fade_in = 0.15
local reverse_arrow_pulse = 0.3

---Only the repeat that ends the current span shows its arrow.
---@param slider rizu.aim.Slider
---@param radius number
---@param time number
---@param alpha number
---@param preempt number
---@param sprites rizu.skin.osu.aim.OsuAimSprites?
function OsuSliderOverlayRenderer.drawReverseArrow(slider, radius, time, alpha, preempt, sprites)
	local timing = slider.timing
	local span = math.max(0, math.floor((time - timing.start_time) / timing.span_duration))
	if span >= timing.spans - 1 then return end
	-- The first arrow waits for the body to finish snaking in.
	local appear_time = span == 0 and timing.start_time - preempt * 2 / 3
		or timing.start_time + span * timing.span_duration
	local repeat_time = timing.start_time + (span + 1) * timing.span_duration
	alpha = alpha * math.min(1, (time - appear_time) / reverse_arrow_fade_in)
	if alpha <= 0 then return end

	local progress = span % 2 == 0 and 1 or 0
	local x, y = slider.path:position(progress)
	local arrow = sprites and sprites.reversearrow
	if not SpriteRenderer.isRenderable(arrow) then
		SpriteRenderer.flush(sprites)
		love.graphics.setLineWidth(2)
		love.graphics.setColor(0.85, 0.95, 1, alpha)
		love.graphics.circle("line", x, y, radius * 0.6)
		return
	end
	-- The arrow points back along the path, the way the ball will leave.
	local inner_x, inner_y = slider.path:position(math.abs(progress - 1e-3))
	local pulse_start = appear_time + math.floor((time - appear_time) / reverse_arrow_pulse) * reverse_arrow_pulse
	local pulse = math.min(1, (time - pulse_start) / math.min(reverse_arrow_pulse, repeat_time - pulse_start))
	local scale = radius / 64 * (1.3 - 0.3 * (2 * pulse - pulse * pulse))
	SpriteRenderer.draw(arrow, x, y, SpriteRenderer.getWidth(arrow) * scale, alpha,
		math.atan2(inner_y - y, inner_x - x))
end

---@param slider rizu.aim.Slider
---@param radius number
---@param time number
---@param alpha number
---@param snake_end number
---@param sprites rizu.skin.osu.aim.OsuAimSprites?
---@param framerate number?
---@param preempt number
function OsuSliderOverlayRenderer.drawBodyOverlays(slider, radius, time, alpha, snake_end, sprites, framerate, preempt)
	if alpha <= 0 then return end
	love.graphics.setLineWidth(2)
	snake_end = math.min(1, math.max(0, snake_end))
	for _, checkpoint in ipairs(slider.timing.checkpoints) do
		if checkpoint.time >= time and checkpoint.kind == "tick" and checkpoint.progress <= snake_end then
			local x, y = slider.path:position(checkpoint.progress)
			local scorepoint = sprites and sprites.sliderscorepoint
			local scorepoint_width = SpriteRenderer.getWidth(scorepoint)
			if scorepoint_width > 0 then
				local size = math.min(radius * 0.5, scorepoint_width)
				SpriteRenderer.draw(scorepoint, x, y, size, alpha)
			else
				SpriteRenderer.flush(sprites)
				love.graphics.setColor(0.85, 0.95, 1, alpha)
				love.graphics.circle("fill", x, y, 4)
			end
		end
	end

	OsuSliderBallRenderer.draw(slider, radius, time, alpha, snake_end, sprites, framerate)
	OsuSliderOverlayRenderer.drawReverseArrow(slider, radius, time, alpha, preempt, sprites)
end

return OsuSliderOverlayRenderer
