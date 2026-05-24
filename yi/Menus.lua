local SkyBackground = require("yi.layers.SkyBackground")
local MainMenu = require("yi.layers.MainMenu")
local Config = require("yi.layers.Config")
local SpringValue = require("ui.anim.SpringValue")

local class = require("class")

---@class yi.Menus
---@overload fun(yi: yi.UserInterface, w: number, h: number): yi.Menus
---@field private screen_springs {[ui.Layer]: ui.anim.SpringValue}
local Menus = class()

---@param yi yi.UserInterface
---@param w number
---@param h number
function Menus:new(yi, w, h)
	self.inputs = yi.inputs

	self.background = SkyBackground(yi)
	self.main_menu = MainMenu(yi)
	self.config = Config(yi)

	self.background:setDimensions(w, h)
	self.main_menu:setDimensions(w, h)
	self.config:setDimensions(w, h)

	self.background:load()
	self.main_menu:load()
	self.config:load()

	self.canvas = love.graphics.newCanvas(w, h)
	self.screen_canvas = love.graphics.newCanvas(w, h)
	self.visiblity = SpringValue({value = 1})

	self.springs_stable = true
	self.screen_springs = {
		[self.main_menu] = SpringValue({value = 1}),
		[self.config] = SpringValue({value = 0})
	}

	self.current_screen = self.main_menu
end

---@param screen string
function Menus:hasScreen(screen)
	return screen == "main_menu" or screen == "config"
end

function Menus:hide()
	self.visiblity:set(0)
end

function Menus:show()
	self.visiblity:set(1)
end

---@param screen string
function Menus:setScreen(screen)
	if screen == "main_menu" then
		self.current_screen = self.main_menu
	elseif screen == "config" then
		self.current_screen = self.config
	end

	self:show()
end

function Menus:isVisible()
	return self.visiblity:get() > 0
end

---@param dt number
function Menus:update(dt)
	self.current_screen:acceptInputs(self.inputs)

	self.springs_stable = true
	for screen, spring in pairs(self.screen_springs) do
		if screen == self.current_screen then
			spring:set(1)
		else
			spring:set(0)
		end
		spring:update(dt)

		if not (spring:get() == 1 or spring:get() == 0) then
			self.springs_stable = false
		end
	end

	self.background:update(dt)
	self.current_screen:update(dt)
	self.visiblity:update(dt)
end

local ww, wh = 0, 0
local st_w, st_h = 0, 0
local st_r = 0

local function menu_stencil()
	love.graphics.push()
	love.graphics.translate(ww / 2, wh / 2)
	love.graphics.rotate(st_r)
	love.graphics.rectangle("fill", -st_w / 2, -st_h / 2, st_w, st_h)
	love.graphics.pop()
end

function Menus:draw()
	local a = self.visiblity:get()

	love.graphics.setBlendMode("alpha", "alphamultiply")
	love.graphics.setCanvas(self.canvas)
	self.background:draw()

	if not self.springs_stable then
		for screen, spring in pairs(self.screen_springs) do
			local a = spring:get()
			if a > 0 then
				love.graphics.setCanvas(self.screen_canvas)
				love.graphics.clear()
				love.graphics.setColor(1, 1, 1)
				love.graphics.setBlendMode("alpha", "alphamultiply")
				screen:draw()
				love.graphics.setCanvas(self.canvas)

				love.graphics.setBlendMode("alpha", "premultiplied")
				love.graphics.setColor(a, a, a, a)
				love.graphics.draw(self.screen_canvas)
			end
		end
	else
		self.current_screen:draw()
	end

	love.graphics.setBlendMode("alpha")

	love.graphics.setColor(1, 1, 1)
	love.graphics.setCanvas()

	love.graphics.setStencilMode("draw", 1)
	ww, wh = love.graphics.getDimensions()
	st_w, st_h = ww * a, wh * a
	st_r = 1 - a
	menu_stencil()
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
