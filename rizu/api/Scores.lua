local thread = require("thread")
local Events = require("rizu.api.Events")
local Settings = require("rizu.config.Settings")
local StoredAccuracies = require("rizu.engine.ScoreEngine.StoredAccuracies")
local Scoring = require("rizu.engine.scoring.Scoring")
local TimingSystems = require("rizu.engine.scoring.TimingSystems")
local Timings = require("sea.chart.Timings")
local Subtimings = require("sea.chart.Subtimings")

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

-- Accuracy systems

---Score systems whose accuracy is stored with every score, the ones getAccuracy() can show.
---"auto" is the chart's own system; the others are tokens such as "osuod:9:1", see getAccuracySystem().
---@return string[]
function Scores:getAccuracySystems()
	return StoredAccuracies.parse(self.selector.settings:getString(Settings.keys.scores.stored_accuracies))
end

---@return string token One of getAccuracySystems(), or "auto".
function Scores:getSelectedAccuracySystem()
	local token = self.selector.settings:getString(Settings.keys.select.accuracy_system)
	for _, stored in ipairs(self:getAccuracySystems()) do
		if stored == token then
			return token
		end
	end
	return "auto"
end

---Systems addAccuracySystem() takes: the ones with an accuracy of their own.
---@return rizu.api.Play.TimingSystem[]
function Scores:getAddableAccuracySystems()
	local systems = {}
	for _, name in ipairs(TimingSystems.selectable) do
		if not TimingSystems.get(name).normalscore then
			table.insert(systems, name)
		end
	end
	return systems
end

---Stores the accuracy of another score system with every new score. Old scores get it in the
---background, the way the library does after an update.
---@param system rizu.api.Play.TimingSystem One of getAddableAccuracySystems().
---@param value number? OD, judge or rank, see `rizu.api.Play.TimingSystem`. The system's default when nil.
---@param osu_score_version 1|2? Only for "osuod", 1 by default.
---@return boolean added false when it is stored already.
function Scores:addAccuracySystem(system, value, osu_score_version)
	value = value or TimingSystems.get(system).default_value
	local subtimings ---@type sea.Subtimings?
	if system == "osuod" then
		subtimings = Subtimings("scorev", osu_score_version or 1)
		-- Slider arithmetic leaves values such as 7.7 just off the exact tenth Timings requires.
		value = math.floor(value * 10 + 0.5) / 10
	end
	local scoring = Scoring(Timings(system, value), subtimings)
	local key = table.concat({scoring:encode()}, ":")
	local tokens = self:getAccuracySystems()
	for _, token in ipairs(tokens) do
		local stored = StoredAccuracies.getScoring(token)
		if stored and table.concat({stored:encode()}, ":") == key then
			return false
		end
	end
	table.insert(tokens, StoredAccuracies.encode(scoring))
	self.selector.settings:setString(Settings.keys.scores.stored_accuracies, table.concat(tokens, ","))
	self.selector.library:updateAccuracies(self.selector.settings)
	return true
end

---Stops storing a score system's accuracy and showing it. "auto" stays.
---@param token string One of getAccuracySystems().
function Scores:removeAccuracySystem(token)
	local tokens = {}
	for _, stored in ipairs(self:getAccuracySystems()) do
		if stored ~= token or token == "auto" then
			table.insert(tokens, stored)
		end
	end
	self.selector.settings:setString(Settings.keys.scores.stored_accuracies, table.concat(tokens, ","))
	if self.selector.settings:getString(Settings.keys.select.accuracy_system) == token then
		self:setSelectedAccuracySystem("auto")
	end
end

---Shows the accuracies of another stored score system. Reloads the list.
---@param token string One of getAccuracySystems().
function Scores:setSelectedAccuracySystem(token)
	self.selector.settings:setString(Settings.keys.select.accuracy_system, token)
	self:refresh()
end

---What a token stands for: its name, how its accuracy is written, its grades.
---@param chart rizu.api.Chart? What "auto" stands for: its auto timings.
---@param token string? The selected one by default.
---@return rizu.engine.scoring.Scoring? scoring nil for "auto" without a loaded chart.
function Scores:getAccuracySystem(chart, token)
	local auto = chart and chart.format and Scoring(TimingSystems.getAuto(chart.chartmeta_timings, chart.format))
	return StoredAccuracies.getScoring(token or self:getSelectedAccuracySystem(), auto)
end

---The accuracy of a score of the selected chart in the selected score system, as text such as "98.50%".
---@param score rizu.api.Score
---@return string? accuracy nil when it is not stored: online scores, and scores played before the system
---was added and not recalculated.
function Scores:getAccuracy(score)
	local scoring = self:getAccuracySystem(self.selector.chartview --[[@as rizu.api.Chart?]])
	if not scoring then
		return
	end
	if scoring:isNormalscore() then
		return scoring:formatAccuracy(score.accuracy)
	end
	-- Online scores have the server's ids.
	if self:getSource() ~= "local" then
		return
	end
	local timings, subtimings = scoring:encode()
	for _, row in ipairs(self.selector.library.chartplayAccuraciesRepo:getAccuracies(score.id)) do
		if row.timings == timings and row.subtimings == subtimings then
			return scoring:formatAccuracy(row.accuracy)
		end
	end
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
