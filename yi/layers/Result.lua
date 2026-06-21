local Screen = require("gui.Screen")
local S = require("gui.composition.Strategies")
local Colors = require("yi.Colors")
local JudgeSegments = require("yi.views.result.JudgeSegments")

---@class yi.layers.Result : gui.Screen
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
		outline = 0.08,
	})
	self.accuracy:setPivot(0.5, 0.5)
	self.judge_segments = JudgeSegments()

	self.chart_header = ChartHeader()
	self.chart_info = ChartInfo()
	self.chart_diff = ChartDifficulty(yi)
	self.gameplay_state = GameplayState()

	self.root = S.Stack({
		S.Track({
			space = {"*", 2, 64},
			S.Stack({
				ui:Image({
					image = "select_bg_gradient",
					fit_box = true,
					color = Colors.select_bg_gradient
				}),

				S.Anchor({
					pivot = {0.5, 0.5},
					self.judge_segments
				}),

				self.accuracy
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

		S.Stack({
			padding = 20,
			self.chart_header,
			S.Anchor({
				pivot = {0, 1},
				S.Flow({
					direction = "column",
					gap = 20,
					S.Flow({
						direction = "row",
						gap = 20,
						align = 1,
						self.chart_diff,
						ui:Rectangle({
							width = 3,
							height = 80,
							fit_box = false,
							color = Colors.line,
							blend_mode = "add"
						}),
						self.gameplay_state
					}),
					ui:Rectangle({
						width = 900,
						height = 3,
						fit_box = false,
						color = Colors.line,
						blend_mode = "add"
					}),
					self.chart_info
				}),
			})
		}),

	})
end

function Result:enter()
	local game = self.yi.game
	local score_engine = game.rhythm_engine.score_engine
	local judge_score = score_engine.judgesSource
	self.judge_segments:bind(judge_score)

	self.accuracy:setText(score_engine.accuracySource:getAccuracyString())

	local cv = game.chartSelector.chartview
	if cv then
		self.chart_info:bind(cv, game.replayBase)
		self.chart_diff:bind(cv, game.timeRateModel:get())
		self.chart_header:bind(cv)
	end
	self.gameplay_state:bind(game.replayBase, game.timeRateModel)
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
