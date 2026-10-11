local OsuImage = require("rizu.skin.osu.OsuImage")
local Shared = require("rizu.skin.base.osu.aim.AimRenderShared")
local SpriteRenderer = require("rizu.skin.osu.aim.OsuSpriteRenderer")

---@class rizu.skin.osu.aim.OsuCircleRenderer
local OsuCircleRenderer = {}

---@param sprites rizu.skin.osu.aim.OsuAimSprites
---@param number integer
---@param x number
---@param y number
---@param scale number
---@param alpha number
local function drawNumber(sprites, number, x, y, scale, alpha)
	local text = tostring(number)
	local overlap = sprites.digit_overlap
	local width = 0
	for i = 1, #text do
		local glyph = sprites.digits[text:byte(i) - 48]
		if glyph then width = width + OsuImage.dimensions(glyph) - overlap end
	end
	if width == 0 then return end
	love.graphics.setColor(1, 1, 1, alpha)
	x = x - (width + overlap) * scale / 2
	for i = 1, #text do
		local glyph = sprites.digits[text:byte(i) - 48]
		if glyph then
			local glyph_width, glyph_height = OsuImage.dimensions(glyph)
			OsuImage.draw(glyph, x, y - glyph_height * scale / 2, 0, scale, scale, 0, 0, sprites.batch)
			x = x + (glyph_width - overlap) * scale
		end
	end
end

---@param object chart.osu.AimObject
---@param radius number
---@param time number
---@param preempt number
---@param sprites rizu.skin.osu.aim.OsuAimSprites?
---@param is_slider_head boolean?
---@param head_state ("hit"|"miss")? Set once the head is resolved; it then fades out.
---@param head_time number? When the head was resolved.
---@param color number[]? Combo colour; tints the circle and its approach circle, not the overlay.
function OsuCircleRenderer.draw(object, radius, time, preempt, sprites, is_slider_head, head_state, head_time, color)
	local remaining = object.time - time
	local age = preempt - remaining
	local alpha = Shared.circleAlpha(age)
	local size = radius * 2
	local number_alpha = alpha
	if head_state then
		local fade_alpha, scale = Shared.headFade(head_state, time - (head_time or time))
		alpha = alpha * fade_alpha
		size = size * scale
		-- osu! drops the number at once when a circle is hit.
		number_alpha = head_state == "hit" and 0 or alpha
	end
	if alpha <= 0 then return end
	local hitcircle = sprites and ((is_slider_head and sprites.sliderstartcircle) or sprites.hitcircle)
	local overlay = sprites and ((is_slider_head and sprites.sliderstartcircleoverlay) or sprites.hitcircleoverlay)
	if not SpriteRenderer.isRenderable(hitcircle) then hitcircle = nil end
	if not SpriteRenderer.isRenderable(overlay) then overlay = nil end

	if remaining > 0 and not head_state then
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
			SpriteRenderer.draw(approachcircle, object.x, object.y, approach_size, approach_alpha, 0, color)
		else
			SpriteRenderer.flush(sprites)
			love.graphics.setColor(0.8, 0.92, 1, approach_alpha)
			love.graphics.circle("line", object.x, object.y, radius * approach)
		end
	end

	if hitcircle then
		SpriteRenderer.draw(hitcircle, object.x, object.y, size, alpha, 0, color)
	else
		SpriteRenderer.flush(sprites)
		love.graphics.setColor(0.16, 0.4, 0.58, alpha)
		love.graphics.circle("fill", object.x, object.y, size / 2)
	end
	if sprites and sprites.digits and object.combo_number and number_alpha > 0 then
		-- Glyphs are authored against osu!'s 128px hit circle texture.
		drawNumber(sprites, object.combo_number, object.x, object.y, radius * 2 / 128 * 0.8, number_alpha)
	end
	if overlay then
		SpriteRenderer.draw(overlay, object.x, object.y, size, alpha)
	elseif not hitcircle then
		SpriteRenderer.flush(sprites)
		local border_width = 2
		love.graphics.setLineWidth(border_width)
		love.graphics.setColor(0.8, 0.92, 1, alpha)
		love.graphics.circle("line", object.x, object.y, (size - border_width) / 2)
	end
end

return OsuCircleRenderer
