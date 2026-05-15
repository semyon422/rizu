local LocalTimer = require("rizu.engine.time.LocalTimer")

---@class rizu.editor.EditorTimeManager: rizu.LocalTimer
---@operator call: rizu.editor.EditorTimeManager
local TimeManager = LocalTimer + {}

return TimeManager
