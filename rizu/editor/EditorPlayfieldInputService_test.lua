local EditorPlayfieldInputService = require("rizu.editor.EditorPlayfieldInputService")

local test = {}

local function createService(calls)
	return EditorPlayfieldInputService({
		playfieldService = {
			isNotesActive = function(_, context)
				return context.notesActive ~= false
			end,
			selectNoteAndGrab = function(_, context, note, part, mouseTime)
				table.insert(calls, ("grab:%s:%s"):format(part, mouseTime))
				context.note = note
			end,
			removeNote = function(_, context, note)
				table.insert(calls, "remove")
				context.note = note
			end,
			addNote = function(_, context, time, columnIndex)
				table.insert(calls, ("add:%s:%s"):format(time, columnIndex))
				context.columnIndex = columnIndex
			end,
			selectStart = function()
				table.insert(calls, "select-start")
			end,
			dropGrabbedNotes = function(_, context, mouseTime)
				table.insert(calls, "drop:" .. mouseTime)
				return context.dropResult
			end,
			selectEndIfSelecting = function(_, context)
				table.insert(calls, "select-end")
				return context.selectEndResult
			end,
		},
	})
end

---@param t testing.T
function test.note_left_press_grabs_first_hovered_part(t)
	local calls = {}
	local context = {}
	local note = {}
	local service = createService(calls)

	t:eq(service:handleNoteInput(context, {
		note = note,
		mouseTime = 1.5,
		leftPressed = true,
		bodyOver = false,
		headOver = true,
		tailOver = true,
	}), true)

	t:eq(context.note, note)
	t:tdeq(calls, {"grab:head:1.5"})
end

---@param t testing.T
function test.note_right_press_removes_hovered_note(t)
	local calls = {}
	local context = {}
	local note = {}
	local service = createService(calls)

	t:eq(service:handleNoteInput(context, {
		note = note,
		mouseTime = 1.5,
		rightPressed = true,
		bodyOver = true,
	}), true)

	t:eq(context.note, note)
	t:tdeq(calls, {"remove"})
end

---@param t testing.T
function test.note_input_ignores_unhovered_note(t)
	local calls = {}
	local service = createService(calls)

	t:eq(service:handleNoteInput({}, {
		note = {},
		mouseTime = 1.5,
		leftPressed = true,
	}), false)

	t:tdeq(calls, {})
end

---@param t testing.T
function test.column_input_adds_note_when_hovered_and_pressed(t)
	local calls = {}
	local context = {}
	local service = createService(calls)

	t:eq(service:handleColumnInput(context, {
		columnIndex = 4,
		time = 2.5,
		over = true,
		leftPressed = true,
	}), true)
	t:eq(context.columnIndex, 4)

	t:eq(service:handleColumnInput(context, {
		columnIndex = 5,
		time = 3.5,
		over = true,
		leftPressed = false,
	}), false)

	t:tdeq(calls, {"add:2.5:4"})
end

---@param t testing.T
function test.select_input_starts_selection_when_hovered_and_pressed(t)
	local calls = {}
	local service = createService(calls)

	t:eq(service:handleSelectInput({}, {
		over = true,
		leftPressed = true,
	}), true)
	t:eq(service:handleSelectInput({}, {
		over = false,
		leftPressed = true,
	}), false)

	t:tdeq(calls, {"select-start"})
end

---@param t testing.T
function test.release_input_drops_and_ends_selection(t)
	local calls = {}
	local service = createService(calls)

	t:eq(service:handleReleaseInput({
		dropResult = true,
		selectEndResult = false,
	}, {
		leftReleased = true,
		mouseTime = 4.5,
	}), true)

	t:eq(service:handleReleaseInput({}, {
		leftReleased = false,
		mouseTime = 5.5,
	}), false)

	t:tdeq(calls, {"drop:4.5", "select-end"})
end

---@param t testing.T
function test.input_is_ignored_when_notes_tab_is_inactive(t)
	local calls = {}
	local service = createService(calls)
	local context = {
		notesActive = false,
		dropResult = true,
		selectEndResult = true,
	}

	t:eq(service:handleNoteInput(context, {
		note = {},
		mouseTime = 1.5,
		leftPressed = true,
		bodyOver = true,
	}), false)
	t:eq(service:handleColumnInput(context, {
		columnIndex = 4,
		time = 2.5,
		over = true,
		leftPressed = true,
	}), false)
	t:eq(service:handleSelectInput(context, {
		over = true,
		leftPressed = true,
	}), false)
	t:eq(service:handleReleaseInput(context, {
		leftReleased = true,
		mouseTime = 4.5,
	}), false)

	t:tdeq(calls, {})
end

return test
