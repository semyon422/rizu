local C = require("yi.renderer.Commands")

local st_w = 0
local st_h = 0
local st_corner_radius = 0
local st_tf ---@type love.Transform

local function stencil()
	love.graphics.push()
	love.graphics.applyTransform(st_tf)
	love.graphics.rectangle("fill", 0, 0, st_w, st_h, st_corner_radius, st_corner_radius)
	love.graphics.pop()
end

local function draw_stencil(stencil_fn, action, value)
	love.graphics.setColorMask(false, false, false, false)
	love.graphics.setStencilState(action, "always", value)
	stencil_fn()
	love.graphics.setColorMask(true, true, true, true)
end

---@param buf yi.CommandBuffer
return function(buf)
	local l = #buf
	local i = 1
	while i <= l do
		local v = buf[i]
		if v == C.PUSH_STATE then
			love.graphics.push("all")
			i = i + 1
		elseif v == C.POP_STATE then
			love.graphics.pop()
			i = i + 1
		elseif v == C.SET_COLOR then
			love.graphics.setColor(buf[i + 1])
			i = i + 2
		elseif v == C.SET_BLEND_MODE then
			local t = buf[i + 1]
			love.graphics.setBlendMode(t[1], t[2])
			i = i + 2
		elseif v == C.APPLY_TRANSFORM then
			love.graphics.applyTransform(buf[i + 1])
			i = i + 2
		elseif v == C.DRAW_DROP_SHADOW then
			error("not implemented")
		elseif v == C.DRAW_BACKGROUND_LAYER then
			local n = buf[i + 1] ---@type yi.View
			local w, h = n:getCalculatedWidth(), n:getCalculatedHeight()
			local cr = n.corner_radius or 0
			love.graphics.rectangle("fill", 0, 0, w, h, cr, cr)
			i = i + 2
		elseif v == C.DRAW_VIEW then
			local n = buf[i + 1] ---@type yi.View
			n:draw()
			i = i + 2
		elseif v == C.DRAW_OUTLINE then
			local n = buf[i + 1] ---@type yi.View
			local w, h = n:getCalculatedWidth(), n:getCalculatedHeight()
			local cr = n.corner_radius or 0
			love.graphics.setLineWidth(n.outline.thickness)
			love.graphics.rectangle("line", 0, 0, w, h, cr, cr)
			i = i + 2
		elseif v == C.STENCIL_START then
			local n = buf[i + 1] ---@type yi.View
			st_w, st_h = n:getCalculatedWidth(), n:getCalculatedHeight()
			st_tf = n.transform.love_transform
			st_corner_radius = n.corner_radius or 0
			draw_stencil(stencil, "replace", 1)
			love.graphics.setStencilState("keep", "greater", 0)
			i = i + 2
		elseif v == C.STENCIL_END then
			love.graphics.setStencilState()
			i = i + 1
		end
	end
end
