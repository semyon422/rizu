local LocalTimer = require("rizu.engine.time.LocalTimer")

---@class rizu.editor.TimeManager: rizu.LocalTimer
---@operator call: rizu.editor.TimeManager
local TimeManager = LocalTimer + {}

return TimeManager
