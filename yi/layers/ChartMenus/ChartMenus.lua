local ScreenContainer = require("yi.ScreenContainer")
local ParallaxBackground = require("yi.views.ParallaxBackground")
local Select = require("yi.layers.ChartMenus.Select")
local ChartLoading = require("yi.layers.ChartMenus.ChartLoading")
local Gameplay = require("yi.layers.ChartMenus.Gameplay")
local Result = require("yi.layers.ChartMenus.Result")
local Editor = require("yi.layers.ChartMenus.Editor")
local Resources = require("yi.Resources")

---@class yi.ChartMenus : yi.ScreenContainer
---@operator call: yi.ChartMenus
---@field screens yi.Screen[]
---@field current_screen yi.Screen
local ChartMenus = ScreenContainer + {}

---@param yi yi.UserInterface
function ChartMenus:new(yi)
	self.inputs = yi.inputs
	self.select = Select(yi)
	self.chart_loading = ChartLoading(yi)
	self.gameplay = Gameplay(yi)
	self.result = Result(yi)
	self.editor = Editor(yi)

	self.background = ParallaxBackground(yi.game.backgroundModel)

	self:initScreens({
		self.select,
		self.chart_loading,
		self.gameplay,
		self.result,
		self.editor
	}, self.select)
end

function ChartMenus:load()
	local scale = Resources.getUIScale()
	self.background.ui_scale = scale
	self.background:load()
	self.background:applyLayout()

	for _, v in ipairs(self.screens) do
		v.ui_scale = scale
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
	self:updateScreens(dt)
end

function ChartMenus:acceptInputs(inputs)
	self.current_screen:acceptInputs(inputs)
end

function ChartMenus:draw()
	love.graphics.push("all")
	love.graphics.applyTransform(self.background.transform)
	self.background:draw()
	love.graphics.pop()

	self:drawScreens(nil)
end

---@param event table
function ChartMenus:receive(event)
	self.current_screen:receive(event)
end

return ChartMenus
