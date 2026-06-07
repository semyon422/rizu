local Screen = require("yi.Screen")
local Loading = require("yi.views.Loading")
local UIFactory = require("yi.UIFactory")
local Colors = require("yi.Colors")
local S = require("gui.composition.Strategies")
local L = require("yi.lang.en")
local thread = require("thread")
local delay = require("delay")

---@class yi.layers.ChartLoading : yi.Screen
---@operator call: yi.layers.ChartLoading
local ChartLoading = Screen + {}

---@param yi yi.UserInterface
function ChartLoading:new(yi)
	Screen.new(self)
	self.yi = yi

	local ui = UIFactory()

	self.root = S.Stack({
		padding = 20,

		S.Anchor({
			pivot = {1, 1},
			S.Flow({
				align = 0.5,
				gap = 20,
				ui:Label({
					font = "bold",
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
		self.yi.game.gameInteractor:loadGameplaySelectedChart()
		delay.sleep(0.01)
		self.yi:setScreen("gameplay")
	end)()
end

return ChartLoading
