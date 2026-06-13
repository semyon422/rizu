local ScreenContainer = require("yi.ScreenContainer")

local MainMenu = require("yi.layers.Menus.MainMenu")
local Config = require("yi.layers.Menus.Config")
local SpringValue = require("gui.anim.SpringValue")

local PingPongBackground = require("yi.views.PingPongBackground")
local CodeDecoration = require("yi.views.CodeDecoration")

---@class yi.Menus : yi.ScreenContainer
---@overload fun(yi: yi.UserInterface): yi.Menus
---@field current_screen yi.Screen
---@field screens yi.Screen[]
---@field private screen_springs {[yi.Screen]: gui.anim.SpringValue}
local Menus = ScreenContainer + {}

---@param yi yi.UserInterface
function Menus:new(yi)
	self.inputs = yi.inputs

	local image = love.graphics.newImage("resources/yi/sky_background.jpg")
	self.background = PingPongBackground(image)
	self.code_decoration = CodeDecoration()

	self.main_menu = MainMenu(yi)
	self.config = Config(yi)

	local w, h = love.graphics.getDimensions()
	self.canvas = love.graphics.newCanvas(w, h)
	self.visiblity = SpringValue({value = 1})

	self:initScreens({
		self.main_menu,
		self.config
	}, self.main_menu)
end

function Menus:load()
	self.background:load()
	self.code_decoration:load()

	for _, v in ipairs(self.screens) do
		v:load()
	end
end

function Menus:hide()
	self.visiblity:set(0)
end

function Menus:show()
	self.visiblity:set(1)
end

function Menus:isVisible()
	return self.visiblity:get() > 0
end

---@param dt number
function Menus:update(dt)
	self.background:update(dt)
	self.code_decoration:update(dt)
	self:updateScreens(dt)
	self.visiblity:update(dt)
end

function Menus:acceptInputs(inputs)
	self.current_screen:acceptInputs(inputs)
end

local canvas_t = {nil, stencil = true}

function Menus:draw()
	local a = self.visiblity:get()
	canvas_t[1] = self.canvas

	love.graphics.setBlendMode("alpha", "alphamultiply")
	love.graphics.setCanvas(canvas_t)

	self.background:draw()
	self.code_decoration:draw()

	self:drawScreens(self.canvas)

	love.graphics.setBlendMode("alpha")

	love.graphics.setColor(1, 1, 1)
	love.graphics.setCanvas()

	love.graphics.clear(false, true, false)
	love.graphics.setStencilMode("draw", 1)
	local ww, wh = love.graphics.getDimensions()
	local st_w, st_h = ww * a, wh * a
	local st_r = 1 - a

	love.graphics.push()
	love.graphics.translate(ww / 2, wh / 2)
	love.graphics.rotate(st_r)
	love.graphics.rectangle("fill", -st_w / 2, -st_h / 2, st_w, st_h)
	love.graphics.pop()

	love.graphics.setStencilMode("test")

	love.graphics.setBlendMode("alpha", "premultiplied")
	love.graphics.draw(self.canvas)
	love.graphics.setBlendMode("alpha")

	love.graphics.setStencilMode("off")
end

---@param event table
function Menus:receive(event)
	self.current_screen:receive(event)
end

return Menus
