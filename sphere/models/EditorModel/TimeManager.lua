local LocalTimer = require("rizu.engine.time.LocalTimer")

---@class sphere.EditorTimeManager: rizu.LocalTimer
---@operator call: sphere.EditorTimeManager
local TimeManager = LocalTimer + {}

return TimeManager
