local InputNote = require("rizu.engine.input.notes.InputNote")

---@class rizu.CatchInputNote: rizu.InputNote
---@operator call: rizu.CatchInputNote
local CatchInputNote = InputNote + {}

CatchInputNote.is_bottom = true

---@param value any
function CatchInputNote:input(value)
	if self.logic_note:getDeltaTime() < 0 then
		return
	end
	self.logic_note:input(value)
end

return CatchInputNote
