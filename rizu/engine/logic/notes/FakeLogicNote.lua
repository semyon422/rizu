local LogicNote = require("rizu.engine.logic.notes.LogicNote")

---@class rizu.FakeLogicNote: rizu.LogicNote
---@operator call: rizu.FakeLogicNote
local FakeLogicNote = LogicNote + {}

FakeLogicNote.column = "key1"
FakeLogicNote.time = 0

function FakeLogicNote:new()
	---@type any[]
	self.inputs = {}
end

---@return chart.Column
function FakeLogicNote:getColumn()
	return self.column
end

---@param value any
function FakeLogicNote:input(value)
	table.insert(self.inputs, {self.time, value})
end

---@return number
function FakeLogicNote:getDeltaTime()
	return self.time
end

return FakeLogicNote
