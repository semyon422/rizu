local class = require("class")

---@class rizu.FakeActiveInputNotes
---@operator call: rizu.FakeActiveInputNotes
local FakeActiveInputNotes = class()

---@param input_notes rizu.InputNote[]
function FakeActiveInputNotes:new(input_notes)
	self.input_notes = input_notes
end

function FakeActiveInputNotes:getNotes()
	return self.input_notes
end

return FakeActiveInputNotes
