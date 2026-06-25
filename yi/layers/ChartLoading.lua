local Screen = require("gui.Screen")
local Loading = require("yi.views.Loading")
local Colors = require("yi.Colors")
local Label = require("yi.views.Label")
local S = require("gui.composition.Strategies")
local thread = require("thread")
local delay = require("delay")

---@class yi.layers.ChartLoading : gui.Screen
---@operator call: yi.layers.ChartLoading
local ChartLoading = Screen + {}

---@param yi yi.UserInterface
function ChartLoading:new(yi)
	Screen.new(self)
	self.yi = yi

	self.root = S.Stack({
		padding = 20,

		S.Anchor({
			pivot = {1, 1},
			S.Flow({
				align = 0.5,
				gap = 20,
				Label({
					font_name = "bold",
					font_size = 36,
					text = "Loading...",
					color = Colors.text
				}),
				Loading(),
			}),
		})
	})
end

function ChartLoading:enter()
	thread.coro(function()
		delay.sleep(0.3)
		local loaded = self.yi.game.gameInteractor:loadGameplaySelectedChartAsync()
		delay.sleep(0.01)
		if loaded then
			self.yi:setScreen("gameplay")
		end
	end)()
end

return ChartLoading
