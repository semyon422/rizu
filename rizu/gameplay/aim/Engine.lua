local RulesEngine = require("rizu.engine.RulesEngine")
local CircleRules = require("rizu.gameplay.aim.CircleRules")
local VirtualInputEvent = require("rizu.input.VirtualInputEvent")

---@class rizu.gameplay.aim.Engine : rizu.RulesEngine
---@operator call: rizu.gameplay.aim.Engine
---@field rules rizu.aim.CircleRules
---@field stacking boolean? False for legacy diagnostic replay geometry.
---@field tracking boolean? False for checkpoint-only legacy replays.
local AimEngine = RulesEngine + {}

function AimEngine:createRules()
	self.checkpoint_sound_index = 0
	self.result_sound_index = 0
	return CircleRules(self.chart, self.stacking, self.tracking)
end

function AimEngine:updateNotes()
	RulesEngine.updateNotes(self)
	local rules = self.rules
	for i = self.checkpoint_sound_index + 1, #rules.checkpoint_events do
		local event = rules.checkpoint_events[i]
		if event.hit then
			self:playSamples(event.sounds)
		end
	end
	self.checkpoint_sound_index = #rules.checkpoint_events
	for i = self.result_sound_index + 1, #rules.events do
		local event = rules.events[i]
		local object = rules.objects[event.index]
		if event.hit and object.kind == "spinner" then
			self:playSamples(object.sounds)
		end
	end
	self.result_sound_index = #rules.events
end

---@param event rizu.VirtualInputEvent
---@return integer? object_index
function AimEngine:receive(event)
	local index = RulesEngine.receive(self, event)
	if index then
		self:playSamples(self.rules.objects[index].sounds)
	end
	return index
end

---@return rizu.ReplayFrame[]
function AimEngine:getAutoplayFrames()
	return CircleRules.autoplay(self.rules.chart, false)
end

---Spinners must see the pause to stop accumulating rotation.
---@return rizu.VirtualInputEvent?
function AimEngine:getPauseEvent()
	if next(self.rules.spinners) then
		return VirtualInputEvent(0, nil, 2)
	end
end

return AimEngine
