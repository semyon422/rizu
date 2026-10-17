local ActiveInputNotes = require("rizu.engine.input.ActiveInputNotes")

local test = {}

---@param t testing.T
function test.all(t)
	---@type rizu.LogicNote[]
	local logic_notes = {}

	local ain = ActiveInputNotes(logic_notes)
	ain:setInputMap({key1 = 1})

	t:assert(not ain:hasAny())
	t:tdeq(ain:getNotes(), {})

	logic_notes[1] = {state = "clear"}

	t:tdeq(ain:getNotes(), {{input_map = {key1 = 1}, logic_note = {state = "clear"}}})
end

return test
