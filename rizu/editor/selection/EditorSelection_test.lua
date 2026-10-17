local EditorSelection = require("rizu.editor.selection.EditorSelection")

local test = {}

local function note(id)
	return {
		startNote = id,
		selected = false,
	}
end

---@param t testing.T
function test.select_single(t)
	local selection = EditorSelection()
	local a = note("a")
	local b = note("b")
	local visibleNotes = {a, b}

	selection:select(a, false, visibleNotes)
	t:eq(a.selected, true)
	t:eq(b.selected, false)
	t:eq(selection.notes.a, a)

	selection:select(b, false, visibleNotes)
	t:eq(a.selected, false)
	t:eq(b.selected, true)
	t:eq(selection.notes.a, nil)
	t:eq(selection.notes.b, b)
end

---@param t testing.T
function test.toggle_keep_others(t)
	local selection = EditorSelection()
	local a = note("a")
	local b = note("b")
	local visibleNotes = {a, b}

	selection:select(a, false, visibleNotes)
	selection:select(b, true, visibleNotes)
	t:eq(selection.notes.a, a)
	t:eq(selection.notes.b, b)

	selection:select(a, true, visibleNotes)
	t:eq(a.selected, false)
	t:eq(b.selected, true)
	t:eq(selection.notes.a, nil)
	t:eq(selection.notes.b, b)
end

---@param t testing.T
function test.rectangle_selection_update(t)
	local selection = EditorSelection()
	local a = note("a")
	local b = note("b")
	b.selecting = true

	selection:start({a, b})
	selection:updateVisible({a, b})

	t:eq(a.selected, false)
	t:eq(b.selected, true)
	t:eq(selection.notes.b, b)

	selection:finish()
	t:eq(selection.selecting, false)
end

return test
