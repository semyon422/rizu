local LocalTimer = require("rizu.engine.time.LocalTimer")

---@class sphere.RhythmTimeManager: rizu.LocalTimer
---@operator call: sphere.RhythmTimeManager
local TimeManager = LocalTimer + {}

return TimeManager
