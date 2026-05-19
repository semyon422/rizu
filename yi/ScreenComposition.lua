local class = require("class")

local SkyBackground = require("yi.layers.SkyBackground")
local MainMenu = require("yi.layers.MainMenu")
--local Multiplayer = require("yi.layers.Multiplayer")
local Config = require("yi.layers.Config")
local Select = require("yi.layers.Select")

local SpringValue = require("ui.anim.SpringValue")

---@class yi.ScreenComposition
---@operator call: yi.ScreenComposition
---@field current_screen yi.Screen
---@field previous_screen yi.Screen?
local ScreenComposition = class()

---@param yi yi.UserInterface
---@param inputs ui.Inputs
function ScreenComposition:new(yi, inputs)
	self.inputs = inputs
	self.sky_menu_background = SkyBackground(yi)
	self.config = Config(yi)
	--self.multiplayer = Multiplayer(yi)
	self.main_menu = MainMenu(yi)
	self.select = Select(yi)

	---@type yi.Screen[]
	self.screens = {
		main_menu = self.main_menu,
		config = self.config,
		--multiplayer = self.multiplayer,
		select = self.select
	}

	local w, h = love.graphics.getDimensions()

	self.sky_menu_background:setDimensions(w, h)
	self.sky_menu_background:load()

	for _, v in pairs(self.screens) do
		v:setDimensions(w, h)
		v:load()
	end

	self.chart_menu_alpha = SpringValue({value = 0})
	self.sky_menu_alpha = SpringValue({value = 0})

	self.sky_menu_canvas = love.graphics.newCanvas(w, h)
	self.chart_menu_canvas = love.graphics.newCanvas(w, h)
	self.shared_layer_canvas = love.graphics.newCanvas(w, h)

	self:setScreen(self.main_menu)
end

---@param screen yi.Screen
function ScreenComposition:setScreen(screen)
	if self.current_screen then
		self.previous_screen = self.current_screen
		self.current_screen:exit()
	end

	self.current_screen = screen
	self.current_screen:enter()
	self.sky_menu_alpha:set(1)

	if
		screen == self.main_menu or
		screen == self.config
	then
		self.chart_menu_alpha:set(0)
		self.sky_menu_alpha:set(1)
	elseif
		screen == self.select
	then
		self.sky_menu_alpha:set(0)
		self.chart_menu_alpha:set(1)
	end
end

---@param dt number
function ScreenComposition:update(dt)
	self.sky_menu_background:update(dt)
	self.chart_menu_alpha:update(dt)
	self.sky_menu_alpha:update(dt)

	for _, v in pairs(self.screens) do
		if v:isVisible() then
			v:update(dt)
		end
	end

	self.current_screen:acceptInputs(self.inputs)
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

function ScreenComposition:draw()
	local sky_menu_visible = self.sky_menu_alpha:get() > 0

	if self.select:isVisible() then self.select:draw() end

	if sky_menu_visible then
		local a = self.sky_menu_alpha:get()

		love.graphics.setBlendMode("alpha", "alphamultiply")
		love.graphics.setCanvas(self.sky_menu_canvas)
		love.graphics.clear()

		self.sky_menu_background:draw()

		if self.config:isVisible() then self.config:draw() end
		--if self.multiplayer:isVisible() then self.multiplayer:draw() end
		if self.main_menu:isVisible() then self.main_menu:draw() end

		love.graphics.setBlendMode("alpha")

		love.graphics.setCanvas()

		love.graphics.setStencilMode("draw", 1)
		ww, wh = love.graphics.getDimensions()
		st_w, st_h = ww * a, wh * a
		st_r = 1 - a
		menu_stencil()
		love.graphics.setStencilMode("test")

		love.graphics.setBlendMode("alpha", "premultiplied")
		love.graphics.draw(self.sky_menu_canvas)
		love.graphics.setBlendMode("alpha")

		love.graphics.setStencilMode("off")
	end
end

---@param event table
function ScreenComposition:receive(event)
	self.current_screen:receive(event)
end

return ScreenComposition
