local class = require("class")

local BaseScore = require("rizu.engine.ScoreEngine.scores.BaseScore")
local HpScore = require("rizu.engine.ScoreEngine.scores.HpScore")
local NormalscoreScore = require("rizu.engine.ScoreEngine.scores.NormalscoreScore")
local MiscScore = require("rizu.engine.ScoreEngine.scores.MiscScore")
local SoundsphereScore = require("rizu.engine.ScoreEngine.scores.SoundsphereScore")
local OsuManiaV1Score = require("rizu.engine.ScoreEngine.scores.OsuManiaV1Score")
local OsuManiaV2Score = require("rizu.engine.ScoreEngine.scores.OsuManiaV2Score")
local QuaverScore = require("rizu.engine.ScoreEngine.scores.QuaverScore")
local EtternaAccuracy = require("rizu.engine.ScoreEngine.scores.EtternaAccuracy")
local EtternaJudges = require("rizu.engine.ScoreEngine.scores.EtternaJudges")
local LunaticRaveScore = require("rizu.engine.ScoreEngine.scores.LunaticRaveScore")

local IAccuracySource = require("rizu.engine.ScoreEngine.IAccuracySource")
local IComboSource = require("rizu.engine.ScoreEngine.IComboSource")
local IHealthsSource = require("rizu.engine.ScoreEngine.IHealthsSource")
local IJudgesSource = require("rizu.engine.ScoreEngine.IJudgesSource")
local IScoreSource = require("rizu.engine.ScoreEngine.IScoreSource")

local ScoreEngineFactory = require("rizu.engine.ScoreEngine.ScoreEngineFactory")

---@class rizu.ScoreEngine
---@operator call: rizu.ScoreEngine
---@field accuracySource rizu.IAccuracySource
---@field comboSource rizu.IComboSource
---@field healthsSource rizu.IHealthsSource
---@field judgesSource rizu.IJudgesSource
---@field scoreSource rizu.IScoreSource
---@field sequence {[string]: table}[]
local ScoreEngine = class()

function ScoreEngine:new()
	---@type rizu.LogicNoteChange[]
	self.events = {}
	self.scores = {}
	self.sequence = {}
	self.scoreSystemsByName = {}
end

---@param chartdiff sea.Chartdiff
function ScoreEngine:load(chartdiff)
	self.chartdiff = chartdiff

	---@type rizu.ScoreSystem[]
	self.scoreSystems = {}

	local by_name = {
		base = BaseScore(),
		hp = HpScore(),
		misc = MiscScore(),
		normalscore = NormalscoreScore(),
		soundsphere = SoundsphereScore(),
	}
	self.scores = by_name

	self:selectDefault()

	---@type {[string]: rizu.ScoreSystem}
	self.scoreSystemsByName = by_name

	for _, v in pairs(by_name) do
		table.insert(self.scoreSystems, v)
		v:setNotesCount(chartdiff.notes_count)
	end
end

function ScoreEngine:selectDefault()
	local scores = self.scores
	self.accuracySource = scores.normalscore
	self.comboSource = scores.base
	self.healthsSource = scores.hp
	self.judgesSource = scores.soundsphere
	self.scoreSource = scores.normalscore
end

---@param t sea.Timings
---@param st sea.Subtimings?
---@param _select boolean?
---@return boolean?
---@return string?
function ScoreEngine:createByTimings(t, st, _select)
	local systems, err = ScoreEngineFactory:get(t, st)
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

	return true
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

	score_system:setNotesCount(self.chartdiff.notes_count)

	for _, event in ipairs(self.events) do
		score_system:receive(event)
	end

	return score_system
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
	for _, scoreSystem in ipairs(self.scoreSystems) do
		scoreSystem:receive(event)
	end

	table.insert(self.events, event)

	local slice = self:getSlice()
	self.slice = slice
	table.insert(self.sequence, slice)
end

return ScoreEngine
