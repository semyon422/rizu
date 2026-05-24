local Note = require("chart.model.notes.Note")

---@alias chart.NoteType
---| "tap"
---| "hold"
---| "laser"
---| "drumroll"
---| "mine"
---| "shade"
---| "fake"
---| "sample"
---| "sprite"

---@class chart.NotechartNote: chart.Note
---@operator call: chart.NotechartNote
---@field type chart.NoteType
---@field data {sounds: {[1]: string, [2]: number}[]?, images: string[]?}
local _Note = Note + {}

_Note.__tostring = Note.__tostring
_Note.__eq = Note.__eq
_Note.__lt = Note.__lt

return _Note
