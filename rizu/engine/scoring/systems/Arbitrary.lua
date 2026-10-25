local TimingSystem = require("rizu.engine.scoring.TimingSystem")

---Hit windows given by the replay itself, counted with normalscore.
---@class rizu.engine.scoring.systems.Arbitrary : rizu.engine.scoring.TimingSystem
---@operator call: rizu.engine.scoring.systems.Arbitrary
local Arbitrary = TimingSystem + {}

Arbitrary.name = "arbitrary"
Arbitrary.label = "Arbitrary"

local function undefined(_, _, subtimings)
	if not subtimings then
		return nil, "undefined for arbitrary timings"
	end
	return nil, "invalid timings-subtimings pair"
end

Arbitrary.getTimingValues = undefined
Arbitrary.createScoreSystems = undefined

return Arbitrary()
