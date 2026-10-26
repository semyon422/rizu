local class = require("class")

---@class rizu.ScoreSystem
---@operator call: rizu.ScoreSystem
---@field judge_accuracy rizu.JudgeAccuracy?
---@field judge_windows rizu.JudgeWindows?
---@field judge_counter rizu.JudgeCounter?
---@field judge_names string[]?
---@field timings sea.Timings?
---@field subtimings sea.Subtimings?
---@field notes_count integer?
---@field judges_count integer?
---@field density number?
---@field inputmode string?
---@field chart chart.Chart?
---@field chart_healths sea.Healths?
local ScoreSystem = class()

---@alias rizu.ScoreSystemHandler string|function|rizu.ScoreSystemHandler[]

---@type {[string]: {[string]: {[string]: rizu.ScoreSystemHandler}}}
ScoreSystem.events = {}

ScoreSystem.hasAccuracy = false
ScoreSystem.hasScore = false
ScoreSystem.hasJudges = false

---@return string
function ScoreSystem:getKey()
	error("not implemented")
end

---What a score system knows of the chart before the first event.
---@class rizu.ScoreSystem.ChartInfo
---@field notes_count integer
---@field judges_count integer? Long notes count twice. Nil when unknown.
---@field density number? Judgeable objects per second of the chart at rate 1. Nil when unknown.
---@field inputmode string?
---@field healths sea.Healths? The chart's own HP value, such as #TOTAL of a BMS chart.
---@field chart chart.Chart? For systems that need its notes. Nil when unknown, such as rescoring from stored hits.

---Called once before the first event. Systems work out their chart-dependent constants here.
---@param info rizu.ScoreSystem.ChartInfo
function ScoreSystem:load(info)
	self.notes_count = info.notes_count
	self.judges_count = info.judges_count
	self.density = info.density
	self.inputmode = info.inputmode
	self.chart_healths = info.healths
	self.chart = info.chart
end

---@param event table
function ScoreSystem:before(event) end

---@param event table
function ScoreSystem:after(event) end

---@param self table
---@param handler rizu.ScoreSystemHandler?
---@param event table
local function handle(self, handler, event)
	if type(handler) == "function" then
		handler(self, event)
	elseif type(handler) == "string" then
		self[handler](self, event)
	elseif type(handler) == "table" then
		for _, h in ipairs(handler) do
			handle(self, h, event)
		end
	end
end

---@param event rizu.LogicNoteChange
function ScoreSystem:receive(event)
	self:before(event)

	local handler =
		self.events[event.type] and
		self.events[event.type][event.old_state] and
		self.events[event.type][event.old_state][event.new_state]

	handle(self, handler, event)

	self:after(event)
end

---@return table
function ScoreSystem:getSlice()
	return {}
end

return ScoreSystem
