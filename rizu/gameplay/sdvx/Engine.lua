local RulesEngine = require("rizu.engine.RulesEngine")
local Rules = require("rizu.gameplay.sdvx.Rules")

---@class rizu.gameplay.sdvx.Engine : rizu.RulesEngine
---@operator call: rizu.gameplay.sdvx.Engine
---@field rules rizu.sdvx.Rules
local SdvxEngine = RulesEngine + {}

function SdvxEngine:createRules()
	return Rules(self.chart)
end

return SdvxEngine
