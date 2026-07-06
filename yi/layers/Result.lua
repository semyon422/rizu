local Screen = require("gui.Screen")
local S = require("gui.composition.Strategies")
local JudgeSegments = require("yi.views.result.JudgeSegments")
local ResultCommands = require("yi.layers.ResultCommands")

---@class yi.layers.Result : gui.Screen
---@operator call: yi.layers.Result
local Result = Screen + {}

---@param ui yi.UserInterface
function Result:new(ui)
	Screen.new(self)
	self.ui = ui
	self.commands = ResultCommands(ui)

	self.judge_segments = JudgeSegments()
	self.judge_segments:setPivot(0.5, 0.5)

	self.root = S.Stack({
		self.judge_segments
	})
end

function Result:enter()
	self.ui.command_registry:pushContext("result", self.commands)

	local game = self.ui.game
	local score_engine = game.rhythm_engine.score_engine
	local judge_score = score_engine.judgesSource

	if not judge_score then
		print("No replay")
		return
	end

	self.judge_segments:bind(judge_score)
end

function Result:exit()
	self.ui.command_registry:popContext("result")
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
