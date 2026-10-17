local InputNote = require("rizu.engine.input.notes.InputNote")

---@class rizu.AimInputNote: rizu.InputNote
---@operator call: rizu.AimInputNote
local AimInputNote = InputNote + {}

AimInputNote.is_bottom = true

return AimInputNote
