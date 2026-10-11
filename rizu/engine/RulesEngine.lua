local RhythmEngine = require("rizu.engine.RhythmEngine")

---@class rizu.Rules
---@field chart chart.Chart
---@field autoplay fun(chart: chart.Chart): rizu.ReplayFrame[]
---@field hits integer
---@field misses integer
---@field window number
---@field update fun(self: rizu.Rules, time: number)
---@field receive fun(self: rizu.Rules, event: rizu.VirtualInputEvent, time: number, paused: boolean): integer?

---Engine of a gamemode whose whole state is one rules object. No scoring yet: only hits and misses.
---@class rizu.RulesEngine : rizu.RhythmEngine
---@operator call: rizu.RulesEngine
---@field rules rizu.Rules
local RulesEngine = RhythmEngine + {}

RulesEngine.marks_paused_input = true

---@return rizu.Rules
function RulesEngine:createRules()
	error("not implemented")
end

function RulesEngine:load()
	self.rules = self:createRules()
end

---@param resources {[string]: string}
function RulesEngine:loadAudio(resources)
	-- These modes play hit sounds from their own judgements.
	self.auto_key_sound = false
	RhythmEngine.loadAudio(self, resources)
end

function RulesEngine:updateNotes()
	self.rules:update(self.time_engine.time)
end

---@param event rizu.VirtualInputEvent
---@return integer? object_index
function RulesEngine:receive(event)
	self:syncTime()
	return self.rules:receive(event, self.time_engine.time, self.paused)
end

---@return rizu.ReplayFrame[]
function RulesEngine:getAutoplayFrames()
	return self.rules.autoplay(self.rules.chart)
end

---@return number
function RulesEngine:getPlayPadding()
	return self.rules.window + 0.5
end

return RulesEngine
