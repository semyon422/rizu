local Layer = require("yi.Layer")
local ParallaxBackground = require("yi.views.ParallaxBackground")
local Select = require("yi.layers.ChartMenus.Select")
local ChartLoading = require("yi.layers.ChartMenus.ChartLoading")
local Gameplay = require("yi.layers.ChartMenus.Gameplay")
local Result = require("yi.layers.ChartMenus.Result")

---@class yi.ChartMenus : yi.Layer
---@operator call: yi.ChartMenus
---@field screens yi.Screen[]
---@field current_screen yi.Screen
local ChartMenus = Layer + {}

---@param yi yi.UserInterface
function ChartMenus:new(yi)
	self.inputs = yi.inputs
	self.select = Select(yi)
	self.chart_loading = ChartLoading(yi)
	self.gameplay = Gameplay(yi)
	self.result = Result(yi)

	self.background = ParallaxBackground(yi.game.backgroundModel)

	self.screens = {
		self.select,
		self.chart_loading,
		self.gameplay,
		self.result
	}

	self.current_screen = self.select
end

function ChartMenus:load()
	self.background:load()

	for _, v in ipairs(self.screens) do
		v:load()
	end
end

function ChartMenus:unload()
	for _, v in ipairs(self.screens) do
		v:unload()
	end
end

function ChartMenus:update(dt)
	self.background:update(dt)
	self.current_screen:update(dt)
end

function ChartMenus:acceptInputs(inputs)
	self.current_screen:acceptInputs(inputs)
end

function ChartMenus:draw()
	love.graphics.push("all")
	self.background:draw()
	love.graphics.pop()
	self.current_screen:draw()
end

---@param event table
function ChartMenus:receive(event)
	self.current_screen:receive(event)
end

return ChartMenus
