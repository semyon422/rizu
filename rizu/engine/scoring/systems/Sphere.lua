local TimingSystem = require("rizu.engine.scoring.TimingSystem")
local SoundsphereTimings = require("sea.timings.sphere.SoundsphereTimings_v1")
local SoundsphereScore = require("rizu.engine.ScoreEngine.scores.SoundsphereScore")

---Rizu's own windows: SoundsphereScore judges, normalscore accuracy.
---@class rizu.engine.scoring.systems.Sphere : rizu.engine.scoring.TimingSystem
---@operator call: rizu.engine.scoring.systems.Sphere
local Sphere = TimingSystem + {}

Sphere.name = "sphere"
Sphere.label = "Rizu"

function Sphere:newTimingValues()
	return SoundsphereTimings:getTimingValues()
end

function Sphere:newScoreSystems()
	return {SoundsphereScore()}
end

return Sphere()
