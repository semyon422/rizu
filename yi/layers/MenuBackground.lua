local Layer = require("yi.Layer")
local composition = require("ui.composition")
local PingPongBackground = require("yi.views.PingPongBackground")
local CodeDecoration = require("yi.views.CodeDecoration")
local PerformanceDisplay = require("yi.views.PerformanceDisplay")

---@class yi.MenuBackground : yi.Layer
---@operator call: yi.MenuBackground
local MenuBackground = Layer + {}

---@param yi yi.UserInterface
function MenuBackground:new(yi)
	Layer.new(self)
	local image = love.graphics.newImage("resources/yi/sky_background.jpg")
	self.background = PingPongBackground(image)
	self.code = CodeDecoration(yi.resources)
	self.performance = PerformanceDisplay(yi.resources, yi.game)
	self.composition_root = composition.Stack({
		self.background,
		self.code,
		self.performance,
	})
end

local ww, wh = 0, 0
local st_w, st_h = 0, 0
local st_r = 0

local function stencilFunc()
	love.graphics.push()
	love.graphics.translate(ww / 2, wh / 2)
	love.graphics.rotate(st_r)
	love.graphics.rectangle("fill", -st_w / 2, -st_h / 2, st_w, st_h)
	love.graphics.pop()
end

function MenuBackground:draw()
	local w, h = love.graphics.getDimensions()
	local a = self.transition:get()
	ww, wh = w, h
	st_w = w * a
	st_h = h * a
	st_r = 1 - a

	self.background.alpha = a
	love.graphics.stencil(stencilFunc, "replace", 1)
	love.graphics.setStencilTest("equal", 1)
	Layer.draw(self)
	love.graphics.setStencilTest()
end

return MenuBackground
