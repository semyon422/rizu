local RulesEngine = require("rizu.engine.RulesEngine")
local Rules = require("rizu.gameplay.taiko.Rules")

---@class rizu.gameplay.taiko.Engine : rizu.RulesEngine
---@operator call: rizu.gameplay.taiko.Engine
---@field rules rizu.taiko.Rules
local TaikoEngine = RulesEngine + {}

function TaikoEngine:createRules()
	self.sound_index = 0
	return Rules(self.chart)
end

function TaikoEngine:updateNotes()
	RulesEngine.updateNotes(self)
	local rules = self.rules
	for i = self.sound_index + 1, #rules.sounds do
		self:playSamples(rules.objects[rules.sounds[i]].sounds)
	end
	self.sound_index = #rules.sounds
end

return TaikoEngine
