local NoteView = require("sphere.views.RhythmView.NoteView")

local test = {}

---@param t testing.T
function test.reuses_time_states(t)
	local note_view = NoteView("LongNote")
	note_view.graphicalNote = {start_dt = 1, end_dt = 2}

	local start_state = note_view:getStartTimeState()
	local end_state = note_view:getEndTimeState()
	t:eq(start_state.dt, 1)
	t:eq(end_state.dt, 2)

	note_view.graphicalNote.start_dt = 3
	note_view.graphicalNote.end_dt = 4
	t:eq(note_view:getStartTimeState(), start_state)
	t:eq(note_view:getEndTimeState(), end_state)
	t:eq(start_state.dt, 3)
	t:eq(end_state.dt, 4)
end

return test
