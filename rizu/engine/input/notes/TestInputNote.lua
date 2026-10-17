local InputNote = require("rizu.engine.input.notes.InputNote")

---@class rizu.TestInputNote: rizu.InputNote
---@operator call: rizu.TestInputNote
local TestInputNote = InputNote + {}

TestInputNote.current_time = 0
TestInputNote.time = 0
TestInputNote.priority = 0

---@param event rizu.VirtualInputEvent
---@return boolean
function TestInputNote:match(event)
	return not not event.pos
end

---@return integer
function TestInputNote:getPriority()
	return self.priority
end

---@param value any
function TestInputNote:input(value) end

---@return number
function TestInputNote:getDeltaTime()
	return self.current_time - self.time
end

return TestInputNote
