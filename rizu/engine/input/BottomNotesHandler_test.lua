local BottomNotesHandler = require("rizu.engine.input.BottomNotesHandler")
local FakeActiveInputNotes = require("rizu.engine.input.FakeActiveInputNotes")
local TestInputNote = require("rizu.engine.input.notes.TestInputNote")

local test = {}

---@param id string
---@param state {[string]: any}
---@return rizu.TestInputNote
local function new_note(id, state)
	local note = TestInputNote()
	note.is_bottom = true
	function note:input(value)
		state.count = state.count + 1
		state[id] = value
	end
	return note
end

---@param t testing.T
function test.bottom_notes(t)

	local state = {count = 0}

	local notes = {
		new_note("a", state),
		new_note("b", state),
	}

	local h = BottomNotesHandler(FakeActiveInputNotes(notes))

	h:update()
	t:tdeq(state, {a = false, b = false, count = 2})

	h:receive({id = 1, pos = false, value = true})
	h:update()
	t:tdeq(state, {a = false, b = false, count = 4})

	h:receive({id = 1, pos = true, value = true})
	h:update()
	t:tdeq(state, {a = true, b = true, count = 6})

	h:receive({id = 1, pos = false, value = true})
	h:update()
	t:tdeq(state, {a = false, b = false, count = 8})

	h:receive({id = 1, pos = false, value = false})
	h:update()
	t:tdeq(state, {a = false, b = false, count = 10})

	h:receive({id = 1, pos = true, value = true})
	h:update()
	t:tdeq(state, {a = true, b = true, count = 12})
end

---@param t testing.T
function test.pause_bottom_notes_keep_pressed_id_changed(t)
	local state = {count = 0}

	local notes = {
		new_note("a", state),
		new_note("b", state),
	}

	local h = BottomNotesHandler(FakeActiveInputNotes(notes))

	h:receive({id = 1, pos = true, value = true})
	h:update()
	t:tdeq(state, {a = true, b = true, count = 2})

	h:receive({id = 1, pos = true, value = false})
	h:receive({id = 2, pos = true, value = true})
	h:update()
	t:tdeq(state, {a = true, b = true, count = 4})
end

---@param t testing.T
function test.is_column_pressed(t)
	local notes = {}
	local h = BottomNotesHandler(FakeActiveInputNotes(notes))

	h:receive({id = 1, column = 1, value = true})
	t:assert(h:isColumnPressed(1))
	t:assert(not h:isColumnPressed(2))

	h:receive({id = 2, column = 2, value = "left"})
	t:assert(h:isColumnPressed(2))

	h:receive({id = 1, column = 1, value = false})
	t:assert(not h:isColumnPressed(1))
	t:assert(h:isColumnPressed(2))
end

return test
