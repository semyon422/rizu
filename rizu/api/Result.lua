local class = require("class")
local thread = require("thread")
local Timings = require("sea.chart.Timings")
local Subtimings = require("sea.chart.Subtimings")
local TimingValuesFactory = require("sea.chart.TimingValuesFactory")
local TimingSystems = require("rizu.engine.scoring.TimingSystems")

--[[
How the last play of the selected chart went, or the score that `ui.api.scores:loadSelectedResult()`
replayed: accuracy, judges, every hit, and what the play was made with.

	local result = ui.api.result
	if result:hasScore() then
		local accuracy, text = result:getAccuracy()
		for i, count in ipairs(result:getJudgeCounts()) do
			drawJudge(result:getJudging():getJudgeNames()[i], count)
		end
	end

Nothing here changes by itself: read it when the result screen is entered and after a score is loaded.
]]

-- TODO: weak spot. There is no result object in the game. The numbers are picked from the rhythm
-- engine, the compute context, the result controller and the shared replay base, and "is this a
-- replayed score" decides which of them is right. A play or a replay should leave one finished result.

---The difficulty of the chart as it was played. The game's row has more fields; these are the contract.
---@class rizu.api.Chartdiff
---@field enps_diff number
---@field osu_diff number
---@field msd_diff number
---@field user_diff number
---@field notes_count integer
---@field judges_count integer notes plus long note ends
---@field duration number seconds at rate 1
---@field rate number
---@field inputmode string e.g. "7key", after modifiers
---@field msd_diff_data table? Etterna's skill ratings by pattern, at the played rate.
---@field msd_diff_rates number[]?

---The system that judged the play. `ui.formatters.ScoreSystemFormatter` names and colors it.
---@class rizu.api.Result.Judging
---@field timings {name: string, data: number}? The same systems as `rizu.api.Play.TimingSystem`, with the value in `data`.
---@field subtimings {name: string, data: number}? osu!mania's score version: name "scorev", the version in `data`.
---@field getJudgeNames fun(self: rizu.api.Result.Judging): string[] From the best judge to the miss.

---One judged note, in the order they were played.
---@class rizu.api.Result.Hit
---@field time number Seconds from the start of the chart.
---@field kind "hit"|"miss"|"early" "early" is a press too far before the note to be a hit.
---@field delta number Seconds off the note, negative is early. 0 unless kind is "hit".
---@field judge integer? Index in getJudgeCounts().
---@field accuracy number Seconds. Normalscore accuracy of the play up to this note.
---@field mean number Seconds. Mean delta of the play up to this note.
---@field normalscore number 0..1, the normalscore of the play up to this note.

---@class rizu.api.Result
---@operator call: rizu.api.Result
---@field private game sphere.GameController
local Result = class()

---@param game sphere.GameController
function Result:new(game)
	self.game = game
end

---@param self rizu.api.Result
---@return sea.Chartplay? chartplay The replayed score, nil after a play.
local function getReplayedScore(self)
	local game = self.game ---@diagnostic disable-line: invisible
	return game.resultController.replay and game.computeContext.chartplay or nil
end

-- What was played

---Difficulty and note counts of the chart as it was played, with the rate and the mutators applied.
---@return rizu.api.Chartdiff? chartdiff nil when nothing was played or loaded yet
function Result:getChartdiff() return self.game.computeContext.chartdiff --[[@as rizu.api.Chartdiff?]] end

---How many times faster than normal the music played.
---@return number
function Result:getRate()
	local score = getReplayedScore(self)
	return score and score.rate or self.game.replayBaseConfigurator.rate
end

---@param self rizu.api.Result
---@return (sea.ReplayBase|rizu.gameplay.ReplayBaseConfigurator)?
local function getReplayBase(self)
	local game = self.game ---@diagnostic disable-line: invisible
	local result_controller = game.resultController
	return result_controller.replay and result_controller.replay_base or game.replayBaseConfigurator
end

---The mutators that changed the chart, in the order they were applied.
---@return rizu.api.Mutator[]
function Result:getMutators()
	local replay_base = getReplayBase(self)
	return replay_base and replay_base.modifiers or {}
end

-- The score

---False when there is nothing to show: no play, a score whose replay did not load,
---or a gamemode that has no scoring.
---@return boolean
function Result:hasScore()
	local score_engine = self.game.rhythm_engine.score_engine
	return score_engine.judgesSource ~= nil and score_engine.accuracySource ~= nil
end

-- The functions below need hasScore().

---@return rizu.api.Result.Judging
function Result:getJudging()
	return self.game.rhythm_engine.score_engine.judgesSource --[[@as rizu.api.Result.Judging]]
end

---@return number accuracy 0..1
---@return string text The way the judging system writes it, "98.52%".
function Result:getAccuracy()
	local source = assert(self.game.rhythm_engine.score_engine.accuracySource)
	return source:getAccuracy(), source:getAccuracyString()
end

---The gauge ended alive and high enough to count as a clear.
---@return boolean
function Result:isPassed()
	return assert(self.game.rhythm_engine.score_engine.healthsSource):isPassed()
end

---The judging system's own score, osu!mania's 1,000,000 for example.
---@return number score
---@return string text The way the judging system writes it.
function Result:getScore()
	local source = assert(self.game.rhythm_engine.score_engine.scoreSource)
	return source:getScore(), source:getScoreString()
end

---How many notes got each judge, in the order of getJudging():getJudgeNames().
---@return integer[]
function Result:getJudgeCounts()
	return assert(self.game.rhythm_engine.score_engine.judgesSource):getJudges()
end

---@return integer max_combo
---@return integer possible A long note counts twice: its press and its release.
function Result:getMaxCombo()
	local source = self.game.rhythm_engine.score_engine.comboSource
	local chartdiff = self.game.computeContext.chartdiff
	-- TODO: IComboSource:getMaxPossibleCombo() should provide this, so score systems can report their own total.
	return source and source:getMaxCombo() or 0, chartdiff and chartdiff.judges_count or 0
end

---Accuracy the way Rizu counts it, whatever system judged the play.
---@return string? text "21.00ms". nil when it was not counted.
function Result:getNormalscoreText()
	local normalscore = self.game.rhythm_engine.score_engine.scores.soundsphere
	return normalscore and normalscore:getAccuracyString()
end

---@class rizu.api.Result.MissCounts
---@field left integer
---@field center integer The middle key of an odd key count.
---@field right integer
---@field scratch integer

---@return rizu.api.Result.MissCounts
function Result:getMissCounts()
	local base = self.game.rhythm_engine.score_engine.scores.base
	return {
		left = base.leftMissCount,
		center = base.centerMissCount,
		right = base.rightMissCount,
		scratch = base.scratchMissCount,
	}
end

---@return integer
function Result:getPauseCount()
	local score = getReplayedScore(self)
	return score and score.pause_count or self.game.rhythm_engine.pause_counter.count
end

-- Hits

---The earliest and the latest a tap note can be hit. Not every "hit" of getHits() is inside it:
---long notes have wider windows.
---@return number? early Seconds, negative. nil when the judging system has no windows.
---@return number? late Seconds.
---@return string? err Why there are no windows, when the game knows.
function Result:getHitWindow()
	local judging = self:getJudging()
	if not judging.timings then
		return
	end
	local timing_values, err = TimingValuesFactory:get(judging.timings, judging.subtimings)
	if not timing_values then
		return nil, nil, err
	end
	local window = timing_values.ShortNote.hit
	return window[1], window[2]
end

---Builds the list on every call: thousands of tables for a long chart. Keep what it returns.
---@return rizu.api.Result.Hit[]
function Result:getHits()
	local score_engine = self.game.rhythm_engine.score_engine
	local judges_source = score_engine.judgesSource
	local key = judges_source and judges_source:getKey()
	local hits = {} ---@type rizu.api.Result.Hit[]
	for i, slice in ipairs(score_engine.sequence) do
		local base, normalscore = slice.base, slice.soundsphere or {}
		local judges = slice[key]
		local is_hit = not base.isMiss and not base.isEarlyHit
		hits[i] = {
			time = base.currentTime,
			kind = base.isMiss and "miss" or base.isEarlyHit and "early" or "hit",
			delta = is_hit and base.deltaTime or 0,
			judge = judges and (judges.visual_judge or judges.last_judge),
			accuracy = normalscore.accuracyAdjusted or 0,
			mean = base.lastMean or 0,
			normalscore = normalscore.score or 0,
		}
	end
	return hits
end

-- Rescoring

---Systems rescore() takes. Their names are those of `rizu.api.Play.TimingSystem`.
---@return string[]
function Result:getRescoreSystems() return TimingSystems.selectable end

---Counts the same play again with another scoring system. What was hit and when stays as played,
---only the judges, accuracy and score are worked out anew, the gauge stays the play's. Read the result again after it.
---It is exact only between judges of Etterna or ranks of LR2, whose hit windows do not change
---with the value. Elsewhere notes that wider windows would catch stay misses.
---@param system string One of getRescoreSystems().
---@param value number? OD, judge or rank. Systems that take none ignore it.
---@param osu_score_version 1|2? Only for "osuod", 1 by default.
---@return boolean? ok
---@return string? err
function Result:rescore(system, value, osu_score_version)
	if not self:hasScore() then
		return nil, "There is no result to rescore."
	end
	local subtimings ---@type sea.Subtimings?
	if system == "osuod" then
		subtimings = Subtimings("scorev", osu_score_version or 1)
		-- Slider arithmetic leaves values such as 7.7 just off the exact tenth Timings requires.
		value = value and math.floor(value * 10 + 0.5) / 10
	end
	return self.game.rhythm_engine.score_engine:rescore(Timings(system, value), subtimings)
end

-- Leaving

---@param self rizu.api.Result
---@param mode "retry"|"replay"
---@param f fun(ok: boolean, err: string?)
local function loadGameplay(self, mode, f)
	local game = self.game ---@diagnostic disable-line: invisible
	thread.coro(function()
		local ok, result = pcall(game.resultController.replayNoteChartAsync, game.resultController,
			mode, game.scoreSelector.chartplay)
		if not ok then
			print("failed to load gameplay:", result)
			return f(false, tostring(result))
		end
		f(result and true or false)
	end)()
end

---Loads the chart to play it again the way the selected score was played.
---Switch to the gameplay screen when f gets true. On failure the error text is the second argument.
---@param f fun(ok: boolean, err: string?)
function Result:retry(f) loadGameplay(self, "retry", f) end

---Loads the chart to watch the selected score's replay.
---Switch to the gameplay screen when f gets true. On failure the error text is the second argument.
---@param f fun(ok: boolean, err: string?)
function Result:watch(f) loadGameplay(self, "replay", f) end

---Call when the result screen is left for song select.
function Result:close() self.game.resultController:unload() end

return Result
