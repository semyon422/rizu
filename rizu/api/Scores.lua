local thread = require("thread")
local Events = require("rizu.api.Events")
local Scoring = require("rizu.engine.scoring.Scoring")
local GameplayTimings = require("rizu.gameplay.GameplayTimings")
local Timings = require("sea.chart.Timings")

--[[
The scores of the selected chart: the leaderboard on song select and on the result screen.

	local scores = ui.api.scores
	for i = 1, scores:getCount() do
		local score = scores:get(i)
		drawRow(score.user_name, score.accuracy, score.rate)
	end
	scores:on("scores_changed", function(loading) ... end)

The list follows the selected chart by itself.
]]

---A row of the leaderboard. Only the fields below are the contract; the game's row has more,
---and they can be renamed at any time.
---@class rizu.api.Score
---@field id integer
---@field score number 0..10000, from accuracy.
---@field accuracy number Seconds. Normalscore accuracy: lower is better.
---@field rating number
---@field rate number How many times faster than normal the music played.
---@field const boolean Constant scroll speed.
---@field modifiers table[] The mutators the play was made with.
---@field pause_count integer
---@field miss_count integer
---@field created_at integer Unix time.
---@field user_name string? Online scores only.
---@field user_avatar string? Online scores only. A url for `ui.api.online:getAvatar()`.
---@field rescored_accuracy number? Internal, use `rizu.api.Scores:getAccuracy()`.

---@alias rizu.api.Scores.Source
---| "local" # Scores set on this computer.
---| "online" # The server's leaderboard for the chart.

---@alias rizu.api.Scores.Event
---| "scores_changed" # The list was replaced. Arguments: loading, true while the new list is on its way.

---@class rizu.api.Scores : rizu.api.Events
---@operator call: rizu.api.Scores
---@field on fun(self: rizu.api.Scores, event: rizu.api.Scores.Event, f: function): fun()
---@field private selector rizu.select.ScoreSelector
---@field private result_controller sphere.ResultController
local Scores = Events + {}

---@param selector rizu.select.ScoreSelector
---@param result_controller sphere.ResultController
function Scores:new(selector, result_controller)
	Events.new(self)
	self.selector = selector
	self.result_controller = result_controller
	selector:onChanged(function(event)
		if event.type == "score_items_changed" then
			self:emit("scores_changed", event.loading and true or false)
		end
	end)
end

---@return integer
function Scores:getCount() return self.selector:getScoreCount() end

---@param index integer
---@return rizu.api.Score? score nil outside 1..getCount()
function Scores:get(index) return self.selector:getScoreAt(index) --[[@as rizu.api.Score?]] end

---@return boolean
function Scores:isLoading() return self.selector:isScoreLoading() end

---@return rizu.api.Scores.Source
function Scores:getSource() return self.selector:getScoreSource() end

---Switches the list and loads it again.
---@param source rizu.api.Scores.Source
function Scores:setSource(source)
	self.selector:setScoreSource(source)
end

---Loads the list again for the selected chart.
---Call it when a screen with a score list is entered: loading may have started before the screen subscribed.
function Scores:refresh() self.selector:pullScore() end

---@param index integer
function Scores:select(index) self.selector:scrollScore(nil, index) end

---@return rizu.api.Score? score
function Scores:getSelected() return self.selector.chartplay --[[@as rizu.api.Score?]] end

-- Accuracy

local normalscore = Scoring(Timings("sphere"))

---The system the leaderboard shows accuracies in: the one picked in the play config.
---@return rizu.engine.scoring.Scoring? scoring nil while auto timings are on: normalscore.
function Scores:getAccuracySystem()
	return GameplayTimings.getPicked(self.selector.settings)
end

---The accuracy of a score in getAccuracySystem(), as text such as "98.50%". Local scores of
---another system were scored again from their stored hits when the list was loaded.
---@param score rizu.api.Score
---@return string? accuracy nil when it cannot be scored: online scores, and local ones without hits.
function Scores:getAccuracy(score)
	local scoring = self:getAccuracySystem() or normalscore
	if scoring:isNormalscore() then
		return scoring:formatAccuracy(score.accuracy)
	end
	local accuracy = score.rescored_accuracy
	return accuracy and scoring:formatAccuracy(accuracy)
end

---Replays the selected score in the background so the result screen can show it.
---f gets false when there is no selected score or its replay could not be loaded.
---@param f fun(ok: boolean, err: string?)
function Scores:loadSelectedResult(f)
	local chartplay = self.selector.chartplay
	if not chartplay then
		return f(false)
	end
	thread.coro(function()
		local ok, err = pcall(function()
			self.result_controller:replayNoteChartAsync("result", chartplay)
		end)
		if not ok then
			print("failed to load score:", err)
		end
		f(ok, not ok and tostring(err) or nil)
	end)()
end

return Scores
