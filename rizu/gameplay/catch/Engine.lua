local RulesEngine = require("rizu.engine.RulesEngine")
local Rules = require("rizu.gameplay.catch.Rules")

---@class rizu.gameplay.catch.Engine : rizu.RulesEngine
---@operator call: rizu.gameplay.catch.Engine
---@field rules rizu.catch.Rules
local CatchEngine = RulesEngine + {}

function CatchEngine:createRules()
	self.sound_index = 0
	return Rules(self.chart)
end

function CatchEngine:updateNotes()
	RulesEngine.updateNotes(self)
	local rules = self.rules
	for i = self.sound_index + 1, #rules.events do
		local event = rules.events[i]
		if event.hit then
			self:playSamples(rules.objects[event.index].sounds)
		end
	end
	self.sound_index = #rules.events
end

return CatchEngine
