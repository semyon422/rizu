local Screen = require("gui.Screen")
local View = require("gui.View")
local FlowContainer = require("gui.layout.FlowContainer")
local Label = require("ui.views.Label")
local Loading = require("ui.screens.chart_loading.Loading")
local thread = require("thread")

---@class ui.screens.chart_loading.ChartLoading : gui.Screen
---@operator call: ui.screens.chart_loading.ChartLoading
local ChartLoading = Screen + {}

---@param ui ui.UserInterface
function ChartLoading:new(ui)
	Screen.new(self)
	self.ui = ui

	local content = self.root:add(FlowContainer({
		direction = "row",
		gap = 20,
		align = 0.5,
	}))

	content:add(Label({
		font_name = "bold",
		font_size = 36,
		text = "Loading...",
	}))
	content:add(Loading())
	content:fitContent()

	content:setAlignment(1, 1)
	content:setPivot(1, 1)
	content:setOffset(-20, -20)

	self.root:setOpacity(0)
end

function ChartLoading:enter()
	self.root:fadeIn(0.3, "OutQuart")
	thread.coro(function()
		local loaded = self.ui.game.gameInteractor:loadGameplaySelectedChartAsync()
		if loaded then
			self.ui:setScreen(self.ui.gameplay, true)
		end
	end)()
end

function ChartLoading:exit()
	Screen.exit(self)
	self.root:fadeOut(0.4, "InQuad")
	return true
end

return ChartLoading
