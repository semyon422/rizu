local Screen = require("gui.Screen")
local S = require("gui.composition.Strategies")
local JudgeSegments = require("yi.views.result.JudgeSegments")

---@class yi.layers.Result : gui.Screen
---@operator call: yi.layers.Result
local Result = Screen + {}

---@param ui yi.UserInterface
function Result:new(ui)
	Screen.new(self)
	self.ui = ui

	self.judge_segments = JudgeSegments()

	self.root = S.Stack({
		S.Anchor({
			pivot = {0.5, 0.5},
			self.judge_segments
		}),
	})
end

function Result:enter()
	local game = self.ui.game
	local score_engine = game.rhythm_engine.score_engine
	local judge_score = score_engine.judgesSource

	if not judge_score then
		print("No replay")
		return
	end

	self.judge_segments:bind(judge_score)
end

function Result:handleKeyDown(key)
	if key == "escape" then
		self.ui:setScreen("select")
	else
		return false
	end

	return true
end

return Result
