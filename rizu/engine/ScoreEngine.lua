local class = require("class")
local table_util = require("table_util")

local BaseScore = require("rizu.engine.ScoreEngine.scores.BaseScore")
local SoundsphereScore = require("rizu.engine.ScoreEngine.scores.SoundsphereScore")

local IAccuracySource = require("rizu.engine.ScoreEngine.IAccuracySource")
local IComboSource = require("rizu.engine.ScoreEngine.IComboSource")
local IHealthsSource = require("rizu.engine.ScoreEngine.IHealthsSource")
local IJudgesSource = require("rizu.engine.ScoreEngine.IJudgesSource")
local IScoreSource = require("rizu.engine.ScoreEngine.IScoreSource")

local Timings = require("sea.chart.Timings")
local Scoring = require("rizu.engine.scoring.Scoring")
local TimingSystems = require("rizu.engine.scoring.TimingSystems")

---@class rizu.ScoreEngine
---@operator call: rizu.ScoreEngine
---@field accuracySource rizu.IAccuracySource?
---@field comboSource rizu.IComboSource?
---@field healthsSource rizu.IHealthsSource?
---@field chart_info rizu.ScoreSystem.ChartInfo Totals of the play, given to load.
---@field charts {info: rizu.ScoreSystem.ChartInfo, first_event: integer}[] The charts begun, so late systems load them in turn.
---@field judgesSource rizu.IJudgesSource?
---@field scoreSource rizu.IScoreSource?
---@field sequence {[string]: table}[]
local ScoreEngine = class()

---@param chartdiff sea.Chartdiff
---@return number?
local function getDensity(chartdiff)
	-- rescoring from stored hits passes a chartdiff without duration
	if chartdiff.duration and chartdiff.judges_count and chartdiff.duration > 0 then
		return chartdiff.judges_count / chartdiff.duration
	end
end

function ScoreEngine:new()
	---@type rizu.LogicNoteChange[]
	self.events = {}
	self.scores = {}
	self.sequence = {}
	self.scoreSystemsByName = {}
	self.charts = {}
	self.index_offset = 0
	self.max_index = -1
end

---@param chartdiff sea.Chartdiff
---@param chart_healths sea.Healths?
---@param chart chart.Chart?
---@return rizu.ScoreSystem.ChartInfo
local function getChartInfo(chartdiff, chart_healths, chart)
	return {
		notes_count = chartdiff.notes_count,
		judges_count = chartdiff.judges_count,
		density = getDensity(chartdiff),
		inputmode = chartdiff.inputmode,
		healths = chart_healths,
		chart = chart,
	}
end

---Loads a single chart.
---@param chartdiff sea.Chartdiff
---@param chart_healths sea.Healths? The chart's own HP value.
---@param chart chart.Chart? For the systems that need the notes.
function ScoreEngine:load(chartdiff, chart_healths, chart)
	local info = getChartInfo(chartdiff, chart_healths, chart)
	self:loadCourse(info)
	self:beginChart(info)
end

---Loads a course: call nextChart before the events of each of its charts.
---@param info rizu.ScoreSystem.ChartInfo Totals of all charts, such as notes_count.
function ScoreEngine:loadCourse(info)
	self.chart_info = info

	---@type rizu.ScoreSystem[]
	self.scoreSystems = {}

	local by_name = {
		base = BaseScore(),
		soundsphere = SoundsphereScore(),
	}
	self.scores = by_name

	self:selectDefault()

	---@type {[string]: rizu.ScoreSystem}
	self.scoreSystemsByName = by_name

	for _, v in pairs(by_name) do
		table.insert(self.scoreSystems, v)
		v:load(self.chart_info)
	end
end

---Takes the events of a play scored before, see rizu.library.ChartplayHits. Only the systems added
---afterwards count them: the default ones stay empty, which saves the time of scoring them.
---@param chartdiff {notes_count: integer, inputmode: string}
---@param events rizu.LogicNoteChange[]
function ScoreEngine:loadEvents(chartdiff, events)
	self:load(chartdiff --[[@as sea.Chartdiff]])
	self.events = events
end

---@param info rizu.ScoreSystem.ChartInfo
function ScoreEngine:beginChart(info)
	-- Note indexes start again in each chart, move them past the ones received so hold states stay apart.
	self.index_offset = self.max_index + 1
	table.insert(self.charts, {info = info, first_event = #self.events + 1})
	for _, v in ipairs(self.scoreSystems) do
		v:loadChart(info)
	end
end

---Continues the course with its next chart.
---@param chartdiff sea.Chartdiff
---@param chart_healths sea.Healths? The chart's own HP value.
---@param chart chart.Chart? For the systems that need the notes.
function ScoreEngine:nextChart(chartdiff, chart_healths, chart)
	self:beginChart(getChartInfo(chartdiff, chart_healths, chart))
end

function ScoreEngine:selectDefault()
	local scores = self.scores
	self.accuracySource = scores.soundsphere
	self.comboSource = scores.base
	self.healthsSource = scores.soundsphere
	self.judgesSource = scores.soundsphere
	self.scoreSource = scores.soundsphere
end

---@param t sea.Timings
---@param st sea.Subtimings?
---@param _select boolean?
---@param healths sea.Healths? The gauge of the play, whatever the timings. Nil is the timings' own.
---@return boolean?
---@return string?
function ScoreEngine:createByTimings(t, st, _select, healths)
	local systems, err = Scoring(t, st):createScoreSystems()
	if not systems then
		if _select then
			self:selectDefault()
		end
		return nil, err
	end

	for _, sys in ipairs(systems) do
		self:addScoreSystem(sys)
		if _select then
			self:select(sys:getKey())
		end
	end
	if _select and healths then
		self:selectHealths(healths, t, st)
	end

	return true
end

---Makes the gauge of a sea.Healths the healths source. Its system judges with the play's timings when
---they are its own, otherwise with its default value. Kinds no system takes, such as bmstotal, change nothing.
---@param healths sea.Healths
---@param t sea.Timings The play's.
---@param st sea.Subtimings?
function ScoreEngine:selectHealths(healths, t, st)
	local system = TimingSystems.getByHealths(healths.name)
	if not system then
		return
	end
	if t.name ~= system.name then
		t, st = Timings(system.name, system.default_value), nil
	end
	for _, sys in ipairs(system:createScoreSystems(t, st, healths) or {}) do
		if IHealthsSource * sys then
			self.healthsSource = self:addScoreSystem(sys) --[[@as rizu.IHealthsSource]]
		end
	end
end

---@param key string
function ScoreEngine:select(key)
	local score = self:getScoreSystem(key)
	if not score then
		self:selectDefault()
		return
	end
	---@cast score any

	self.accuracySource = IAccuracySource * score and score or self.accuracySource
	self.comboSource = IComboSource * score and score or self.comboSource
	self.healthsSource = IHealthsSource * score and score or self.healthsSource
	self.judgesSource = IJudgesSource * score and score or self.judgesSource
	self.scoreSource = IScoreSource * score and score or self.scoreSource
end

---@param key string
---@return rizu.ScoreSystem?
function ScoreEngine:getScoreSystem(key)
	return self.scoreSystemsByName[key]
end

---@param score_system rizu.ScoreSystem
---@return rizu.ScoreSystem
function ScoreEngine:addScoreSystem(score_system)
	local key = score_system:getKey()

	local by_name = self.scoreSystemsByName
	if by_name[key] then
		return by_name[key]
	end

	table.insert(self.scoreSystems, score_system)
	by_name[key] = score_system

	score_system:load(self.chart_info)

	-- Late systems fill the slices of the events that already happened, so the sequence stays whole.
	local charts = self.charts
	local c = 1
	for i = 1, #self.events + 1 do
		while charts[c] and charts[c].first_event == i do
			score_system:loadChart(charts[c].info)
			c = c + 1
		end
		local event = self.events[i]
		if event then
			score_system:receive(event)
			local slice = self.sequence[i]
			if slice then
				slice[key] = score_system:getSlice()
			end
		end
	end

	return score_system
end

---Scores the events received so far with another system and makes it the selected one, except for the
---healths source: the gauge stays the play's. Hit windows are not touched: the events already hold what was hit and when.
---@param t sea.Timings
---@param st sea.Subtimings?
---@return boolean?
---@return string?
function ScoreEngine:rescore(t, st)
	local systems, err = Scoring(t, st):createScoreSystems()
	if not systems then
		return nil, err
	end

	local healths_source = self.healthsSource
	self:selectDefault()
	for _, sys in ipairs(systems) do
		self:select(self:addScoreSystem(sys):getKey())
	end
	self.healthsSource = healths_source

	return true
end

---@return {[string]: table}
function ScoreEngine:getSlice()
	---@type {[string]: table}
	local slice = {}
	for _, scoreSystem in ipairs(self.scoreSystems) do
		slice[scoreSystem:getKey()] = scoreSystem:getSlice()
	end
	return slice
end

---@param event rizu.LogicNoteChange
function ScoreEngine:receive(event)
	if self.index_offset ~= 0 then
		event = table_util.copy(event)
		event.index = event.index + self.index_offset
	end
	self.max_index = math.max(self.max_index, event.index)

	for _, scoreSystem in ipairs(self.scoreSystems) do
		scoreSystem:receive(event)
	end

	table.insert(self.events, event)

	local slice = self:getSlice()
	self.slice = slice
	table.insert(self.sequence, slice)
end

return ScoreEngine
