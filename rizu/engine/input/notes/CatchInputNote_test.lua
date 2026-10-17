local CatchInputNote = require("rizu.engine.input.notes.CatchInputNote")
local FakeLogicNote = require("rizu.engine.logic.notes.FakeLogicNote")

local function new_test_ctx()
	local logic_note = FakeLogicNote()
	local input_note = CatchInputNote(logic_note)

	return {
		logic_note = logic_note,
		input_note = input_note,
	}
end

local test = {}

-- TODO: input event should be handled as at 0 delta time

---@param t testing.T
function test.passed_exact(t)
	local ctx = new_test_ctx()

	ctx.logic_note.time = -1
	ctx.input_note:input(true)

	t:tdeq(ctx.logic_note.inputs, {})

	ctx.logic_note.time = 1
	ctx.input_note:input(true)

	t:tdeq(ctx.logic_note.inputs, {{1, true}})
end

return test
