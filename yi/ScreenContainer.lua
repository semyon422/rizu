local Layer = require("yi.Layer")
local SpringValue = require("gui.anim.SpringValue")

---@class yi.ScreenContainer : yi.Layer
---@operator call: yi.ScreenContainer
---@field current_screen yi.Screen
---@field screens yi.Screen[]
---@field screen_springs {[yi.Screen]: gui.anim.SpringValue}
---@field springs_stable boolean
---@field screen_canvas love.Canvas
local ScreenContainer = Layer + {}

---@param screens yi.Screen[]
---@param initial_screen yi.Screen
function ScreenContainer:initScreens(screens, initial_screen)
	self.screens = screens
	self.current_screen = initial_screen
	self.screen_springs = {}
	for _, screen in ipairs(self.screens) do
		self.screen_springs[screen] = SpringValue({value = screen == self.current_screen and 1 or 0})
	end
	self.springs_stable = true
	local w, h = love.graphics.getDimensions()
	self.screen_canvas = love.graphics.newCanvas(w, h)
end

---@param dt number
function ScreenContainer:updateScreens(dt)
	self.springs_stable = true
	for _, screen in ipairs(self.screens) do
		local spring = self.screen_springs[screen]
		if screen == self.current_screen then
			spring:set(1)
		else
			spring:set(0)
		end
		spring:update(dt)

		if not (spring:get() == 1 or spring:get() == 0) then
			self.springs_stable = false
		end

		if spring:get() > 0 then
			screen:update(dt)
		end
	end
end

local draw_canvas_t = {nil, stencil = true}

---@param target_canvas love.Canvas?
function ScreenContainer:drawScreens(target_canvas)
	if not self.springs_stable then
		for _, screen in ipairs(self.screens) do
			local sa = self.screen_springs[screen]:get()
			if sa > 0 then
				draw_canvas_t[1] = self.screen_canvas
				love.graphics.setCanvas(draw_canvas_t)
				love.graphics.clear()
				love.graphics.setColor(1, 1, 1)
				love.graphics.setBlendMode("alpha", "alphamultiply")
				screen:draw()

				draw_canvas_t[1] = target_canvas
				love.graphics.setCanvas(draw_canvas_t)

				love.graphics.setBlendMode("alpha", "premultiplied")
				love.graphics.setColor(sa, sa, sa, sa)
				love.graphics.draw(self.screen_canvas)
			end
		end
		love.graphics.setBlendMode("alpha")
	else
		love.graphics.setColor(1, 1, 1)
		self.current_screen:draw()
	end
end

return ScreenContainer
