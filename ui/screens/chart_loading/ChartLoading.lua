local Screen = require("gui.Screen")
local View = require("gui.View")
local Flow = require("gui.layout.Flow")
local Label = require("ui.views.Label")
local Loading = require("ui.screens.chart_loading.Loading")
local thread = require("thread")
local delay = require("delay")

---@class ui.screens.chart_loading.ChartLoading : gui.Screen
---@operator call: ui.screens.chart_loading.ChartLoading
local ChartLoading = Screen + {}

---@param ui ui.UserInterface
function ChartLoading:new(ui)
	Screen.new(self)
	self.ui = ui

	local content = self.root:add(View())
	content:setAlignment(1, 1)
	content:setPivot(1, 1)
	content:setOffset(-20, -20)
	content.arrange_strategy = Flow({
		direction = "row",
		gap = 20,
		align = 0.5,
	})

	local label = content:add(Label({
		font_name = "bold",
		font_size = 36,
		text = "Loading...",
	}))

	local loading = content:add(Loading())
	local loading_width = loading.offset_max[1] - loading.offset_min[1]
	local loading_height = loading.offset_max[2] - loading.offset_min[2]
	content:setSize(label.offset_max[1] + 20 + loading_width, math.max(label.offset_max[2], loading_height))
end

function ChartLoading:enter()
	thread.coro(function()
		local loaded = self.ui.game.gameInteractor:loadGameplaySelectedChartAsync()
		if loaded then
			self.ui:setScreen(self.ui.gameplay)
		end
	end)()
end

return ChartLoading
