local Screen = require("yi.Screen")
local S = require("gui.composition.Strategies")
local UIFactory = require("yi.UIFactory")
local Colors = require("yi.Colors")
local JudgeSegments = require("yi.views.result.JudgeSegments")

---@class yi.layers.Result : yi.Screen
---@operator call: yi.layers.Result
local Result = Screen + {}

---@param yi yi.UserInterface
function Result:new(yi)
	Screen.new(self)
	self.yi = yi

	local ui = UIFactory()

	self.accuracy = ui:Label({
		font = "bold",
		font_size = 128,
		text = "??.??%",
		color = Colors.text,
	})
	self.accuracy:setPivot(0.5, 0.5)
	self.judge_segments = JudgeSegments()

	self.root = S.Stack({
		S.Track({
			space = {"*", 2, 64},
			S.Stack({
				ui:Image({
					image = "select_bg_gradient",
					fit_box = true,
					color = Colors.select_bg_gradient
				}),
			}),
			ui:Rectangle({
				fit_box = true,
				color = Colors.line
			}),
			S.Stack({
				ui:Rectangle({
					fit_box = true,
					color = Colors.select_side_panel_bg
				}),
			})
		}),

		S.Anchor({
			pivot = {0.5, 0.5},
			self.judge_segments
		}),

		self.accuracy
	})
end

function Result:enter()
	local game = self.yi.game
	local score_engine = game.rhythm_engine.score_engine
	local judge_score = score_engine.judgesSource
	self.judge_segments:bind(judge_score)

	self.accuracy:setText(score_engine.accuracySource:getAccuracyString())
end

function Result:handleKeyDown(key)
	if key == "escape" then
		self.yi:setScreen("select")
	elseif key == "c" then
		self.yi:setScreen("config")
	else
		return false
	end

	return true
end

return Result
