local class = require("class")
local ChartBackground = require("yi.layers.ChartBackground")
local Select = require("yi.layers.Select")
local Gameplay = require("yi.layers.Gameplay")
local ChartLoading = require("yi.layers.ChartLoading")
local Result = require("yi.layers.Result")
local SpringValue = require("gui.anim.SpringValue")

---@class yi.ChartMenus
---@operator call: yi.ChartMenus
---@field private screen_springs {[gui.Layer]: gui.anim.SpringValue}
local ChartMenus = class()

---@param yi yi.UserInterface
---@param w number
---@param h number
function ChartMenus:new(yi, w, h)
	self.inputs = yi.inputs
	self.chart_background = ChartBackground(yi)
	self.select = Select(yi)
	self.gameplay = Gameplay(yi)
	self.chart_loading = ChartLoading(yi)
	self.result = Result(yi)

	self.chart_background:setDimensions(w, h)
	self.select:setDimensions(w, h)
	self.gameplay:setDimensions(w, h)
	self.chart_loading:setDimensions(w, h)
	self.result:setDimensions(w, h)

	self.chart_background:load()
	self.select:load()
	self.gameplay:load()
	self.chart_loading:load()
	self.result:load()

	self.springs_stable = true
	self.screen_springs = {
		[self.select] = SpringValue({value = 1}),
		[self.chart_loading] = SpringValue({value = 0}),
		[self.gameplay] = SpringValue({value = 0}),
		[self.result] = SpringValue({value = 0})
	}

	self.screen_canvas = love.graphics.newCanvas(w, h)
	self.current_screen = self.select
end

function ChartMenus:unload() end

---@param screen string
function ChartMenus:hasScreen(screen)
	return
		screen == "select" or
		screen == "gameplay" or
		screen == "chart_loading" or
		screen == "result"
end

---@param screen string
function ChartMenus:setScreen(screen)
	if screen == "select" then
		self.current_screen = self.select
	elseif screen == "chart_loading" then
		self.current_screen = self.chart_loading
		self.chart_loading:transitToGameplay()
	elseif screen == "gameplay" then
		self.current_screen = self.gameplay
		self.gameplay:start()
	elseif screen == "result" then
		self.current_screen = self.result
	end
end

function ChartMenus:update(dt)
	self.current_screen:acceptInputs(self.inputs)
	self.chart_background:update(dt)
	self.current_screen:update(dt)

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
end

function ChartMenus:draw()
	self.chart_background:draw()

	if not self.springs_stable then
		for screen, spring in pairs(self.screen_springs) do
			local a = spring:get()
			if a > 0 then
				love.graphics.setCanvas(self.screen_canvas)
				love.graphics.clear()
				love.graphics.setColor(1, 1, 1)
				love.graphics.setBlendMode("alpha", "alphamultiply")
				screen:draw()
				love.graphics.setCanvas()

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
end

---@param event table
function ChartMenus:receive(event)
	self.current_screen:receive(event)
end

return ChartMenus
