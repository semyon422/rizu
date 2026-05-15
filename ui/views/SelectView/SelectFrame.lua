local gfx_util = require("gfx_util")

local Layout = require("ui.views.SelectView.Layout")

local invertShader, baseShader, baseCanvas, inFrame
return function()
	if inFrame then
		love.graphics.setShader(baseShader)
		love.graphics.setCanvas({baseCanvas, stencil = true})
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.origin()
		love.graphics.setBlendMode("alpha", "premultiplied")
		love.graphics.draw(gfx_util.getCanvas(1))
		love.graphics.setBlendMode("alpha")
		love.graphics.pop()
		inFrame = false
		return
	end
	inFrame = true

	invertShader = invertShader or love.graphics.newShader [[
		extern vec4 rect;
		vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
			vec4 pixel = Texel(texture, texture_coords);
			if (screen_coords.x > rect.x && screen_coords.x < rect.x + rect.z && screen_coords.y > rect.y && screen_coords.y < rect.y + rect.w) {
				pixel.r = 1 - pixel.r;
				pixel.g = 1 - pixel.g;
				pixel.b = 1 - pixel.b;
			}
			return pixel * color;
		}
	]]

	love.graphics.push()
	love.graphics.origin()

	baseShader = love.graphics.getShader()
	baseCanvas = love.graphics.getCanvas()

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setCanvas({gfx_util.getCanvas(1), stencil = true})
	love.graphics.clear()

	local w, h = Layout:move("column3")
	h = h / 11
	love.graphics.translate(0, 5 * h)

	love.graphics.setColor(1, 0.7, 0.2, 1)
	love.graphics.rectangle("fill", 0, 0, w, h, h / 2)
	love.graphics.setColor(1, 1, 1, 1)

	love.graphics.setShader(invertShader)

	local _x, _y = love.graphics.transformPoint(0, 0)
	local _xw, _yh = love.graphics.transformPoint(w, h)
	local _w, _h = _xw - _x, _yh - _y

	invertShader:send("rect", {_x, _y, _w, _h})

	love.graphics.pop()
	love.graphics.push()
end
