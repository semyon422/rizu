local SpriteRenderer = require("rizu.skin.osu.aim.OsuSpriteRenderer")

---@class rizu.skin.osu.aim.OsuSliderBallRenderer
local OsuSliderBallRenderer = {}

---@param slider rizu.aim.Slider
---@param radius number
---@param time number
---@param alpha number
---@param snake_end number
---@param sprites rizu.skin.osu.aim.OsuSkinGraphics.Sprites?
---@param framerate number?
function OsuSliderBallRenderer.draw(slider, radius, time, alpha, snake_end, sprites, framerate)
	if alpha <= 0 then return end
	local timing = slider.timing
	if time < timing.start_time or time > timing.end_time then return end
	local progress = timing:progress(time)
	if progress > snake_end then return end
	local x, y = slider.path:position(progress)

	local span = math.min(timing.spans - 1,
		math.floor((time - timing.start_time) / timing.span_duration))
	local reverse = span % 2 == 1
	local epsilon = 1e-3
	---@type number
	local first_progress
	---@type number
	local last_progress
	if reverse then
		first_progress, last_progress = math.min(1, progress + epsilon), math.max(0, progress - epsilon)
	else
		first_progress, last_progress = math.max(0, progress - epsilon), math.min(1, progress + epsilon)
	end
	---@type number, number
	local first_x, first_y = slider.path:position(first_progress)
	---@type number, number
	local last_x, last_y = slider.path:position(last_progress)
	local rotation = math.atan2(last_y - first_y, last_x - first_x)

	local follow = sprites and sprites.sliderfollowcircle
	if SpriteRenderer.isRenderable(follow) then
		SpriteRenderer.draw(follow, x, y, radius * 4.8, alpha)
	else
		love.graphics.setColor(1, 0.85, 0.35, 0.25 * alpha)
		love.graphics.circle("line", x, y, radius * 2.4)
	end

	local frames = sprites and sprites.sliderb
	if frames and #frames > 0 then
		local elapsed = math.max(0, time - timing.start_time)
		local rate = framerate and framerate > 0 and framerate or 14
		local frame_index = math.floor(elapsed * rate) % #frames + 1
		local frame = frames[frame_index]
		if SpriteRenderer.isRenderable(frame) then
			SpriteRenderer.draw(frame, x, y, radius * 2, alpha, rotation)
		end
	end
end

return OsuSliderBallRenderer
