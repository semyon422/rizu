local RhythmEngine = require("rizu.engine.RhythmEngine")

local InputEngine = require("rizu.engine.input.InputEngine")
local ActiveInputNotes = require("rizu.engine.input.ActiveInputNotes")

local LogicInfo = require("rizu.engine.logic.LogicInfo")
local LogicEngine = require("rizu.engine.logic.LogicEngine")

local VisualEngine = require("rizu.engine.visual.VisualEngine")

local ScoreEngine = require("rizu.engine.ScoreEngine")

---@class rizu.gameplay.mania.Engine : rizu.RhythmEngine
---@operator call: rizu.gameplay.mania.Engine
local ManiaEngine = RhythmEngine + {}

ManiaEngine.logic_offset = 0

function ManiaEngine:new()
	RhythmEngine.new(self)

	self.logic_info = LogicInfo()

	self.logic_engine = LogicEngine(self.logic_info)

	self.active_input_notes = ActiveInputNotes(self.logic_engine.active_notes)
	self.input_engine = InputEngine(self.active_input_notes)

	self.visual_engine = VisualEngine(self.visual_info)

	self.score_engine = ScoreEngine()
	function self.logic_info.on_note_change(change)
		self.score_engine:receive(change)
	end
end

function ManiaEngine:load()
	local chart = self.chart
	self.active_input_notes:setInputMap(chart.inputMode:getInputMap())
	self.logic_engine:load(chart)
	self.visual_engine:load(chart)
	self.score_engine.chart_healths = self.chartmeta.healths
	self.score_engine.chart = chart
	self.score_engine:load(self.chartdiff)
	self.pause_counter:new()

	self.visual_info.logic_notes = self.logic_engine.linked_to_logic
end

---@return boolean
function ManiaEngine:hasResult()
	local time_engine = self.time_engine
	local base = self.score_engine.scores.base
	local accuracy = self.score_engine.scores.normalscore.accuracyAdjusted

	return
		not time_engine.wind_up and
		time_engine.time >= self.play_progress.start_time and
		base.hitCount > 0 and
		accuracy > 0 and
		accuracy < math.huge
end

function ManiaEngine:unload()
	RhythmEngine.unload(self)
	self.visual_engine = nil
	self.logic_engine = nil
	self.input_engine = nil
	self.score_engine = nil
end

function ManiaEngine:syncTime()
	RhythmEngine.syncTime(self)
	self.logic_info.time = self:getLogicTime()
end

---Rounded to 1/1024 so that the shifted times stay exact in floating point.
---@param offset number
function ManiaEngine:setInputOffset(offset)
	self.logic_offset = math.floor(offset * 1024) / 1024
end

---@return number
function ManiaEngine:getLogicTime()
	return self.time_engine.time - self.logic_offset
end

function ManiaEngine:updateNotes()
	self.input_engine:update()
	self.logic_engine:update()
	self.visual_engine:update()
end

---@param pending_resync boolean?
function ManiaEngine:play(pending_resync)
	RhythmEngine.play(self, pending_resync)
	self.input_engine:resume()
end

function ManiaEngine:pause()
	RhythmEngine.pause(self)
	self.input_engine:pause()
end

---@param event rizu.VirtualInputEvent
function ManiaEngine:receive(event)
	self:syncTime()
	local input_note, catched = self.input_engine:receive(event)

	if not self.auto_key_sound and event.value == true and catched then
		local logic_note = input_note and input_note.logic_note

		if logic_note then
			self:playSamples(logic_note.linked_note.startNote.data.sounds)
		end
	end
end

---@param timings sea.Timings?
---@param subtimings sea.Subtimings?
---@param healths sea.Healths?
function ManiaEngine:setTimings(timings, subtimings, healths)
	timings = assert(timings or self.chartmeta.timings)
	self.score_engine:createByTimings(timings, subtimings, true, healths)
end

---@param timing_values sea.TimingValues
function ManiaEngine:setTimingValues(timing_values)
	self.logic_info.timing_values = timing_values
end

---@param rate number
function ManiaEngine:setRate(rate)
	RhythmEngine.setRate(self, rate)
	self.logic_info.rate = rate
end

---@param nearest boolean
function ManiaEngine:setNearest(nearest)
	self.input_engine.nearest = nearest
end

---@param const boolean
function ManiaEngine:setConst(const)
	self.time_engine.const = const
	self.visual_info.const = const
end

---@param column integer
---@return boolean
function ManiaEngine:isColumnPressed(column)
	return self.input_engine:isColumnPressed(column)
end

---@param shortening number
function ManiaEngine:setLongNoteShortening(shortening)
	self.visual_info.shortening = shortening
end

---@param wind_up string
function ManiaEngine:setWindUp(wind_up)
end

return ManiaEngine
