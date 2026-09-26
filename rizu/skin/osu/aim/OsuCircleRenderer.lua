local Shared = require("rizu.skin.base.osu.aim.AimRenderShared")
local SpriteRenderer = require("rizu.skin.osu.aim.OsuSpriteRenderer")

---@class rizu.skin.osu.aim.OsuCircleRenderer
local OsuCircleRenderer = {}

---@param object chart.osu.AimObject
---@param radius number
---@param time number
---@param preempt number
---@param sprites rizu.skin.osu.aim.OsuSkinGraphics.Sprites?
---@param is_slider_head boolean?
function OsuCircleRenderer.draw(object, radius, time, preempt, sprites, is_slider_head)
	local remaining = object.time - time
	local age = preempt - remaining
	local alpha = Shared.circleAlpha(age)
	if alpha <= 0 then return end
	local hitcircle = sprites and ((is_slider_head and sprites.sliderstartcircle) or sprites.hitcircle)
	local overlay = sprites and ((is_slider_head and sprites.sliderstartcircleoverlay) or sprites.hitcircleoverlay)
	if not SpriteRenderer.isRenderable(hitcircle) then hitcircle = nil end
	if not SpriteRenderer.isRenderable(overlay) then overlay = nil end

	if remaining > 0 then
		local approach_alpha = Shared.approachAlpha(age, preempt)
		local approach = 1 + 3 * remaining / preempt
		local approachcircle = sprites and sprites.approachcircle
		local approach_size = radius * 2 * approach
		if SpriteRenderer.isRenderable(approachcircle) then
			local circle_width = hitcircle and SpriteRenderer.getWidth(hitcircle) or 0
			local approach_width = SpriteRenderer.getWidth(approachcircle)
			if circle_width > 0 and approach_width > 0 then
				approach_size = approach_size * approach_width / circle_width
			end
			SpriteRenderer.draw(approachcircle, object.x, object.y, approach_size, approach_alpha)
		else
			love.graphics.setColor(0.8, 0.92, 1, approach_alpha)
			love.graphics.circle("line", object.x, object.y, radius * approach)
		end
	end

	if hitcircle then
		SpriteRenderer.draw(hitcircle, object.x, object.y, radius * 2, alpha)
	else
		love.graphics.setColor(0.16, 0.4, 0.58, alpha)
		love.graphics.circle("fill", object.x, object.y, radius)
	end
	if overlay then
		SpriteRenderer.draw(overlay, object.x, object.y, radius * 2, alpha)
	elseif not hitcircle then
		local border_width = 2
		love.graphics.setLineWidth(border_width)
		love.graphics.setColor(0.8, 0.92, 1, alpha)
		love.graphics.circle("line", object.x, object.y, radius - border_width / 2)
	end
end

return OsuCircleRenderer
