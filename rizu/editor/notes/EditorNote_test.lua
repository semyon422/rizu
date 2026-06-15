local EditorNote = require("rizu.editor.notes.EditorNote")

local test = {}

---@param t testing.T
function test.interaction_state_tracks_hover_and_selection(t)
	local note = EditorNote("ShortNote")

	local state = note:getInteractionState()
	t:eq(state.bodyOver, false)
	t:eq(note.selecting, false)

	note:setPartInteractionState("body", true, true)
	state = note:getInteractionState()

	t:eq(state.bodyOver, true)
	t:eq(state.bodySelecting, true)
	t:eq(note.selecting, true)

	note:clearInteractionState()
	state = note:getInteractionState()

	t:eq(state.bodyOver, false)
	t:eq(state.bodySelecting, false)
	t:eq(note.selecting, false)
end

---@param t testing.T
function test.long_note_selection_is_aggregated_from_parts(t)
	local note = EditorNote("LongNote")

	note:setPartInteractionState("head", false, true)
	note:setPartInteractionState("tail", true, false)

	local state = note:getInteractionState()
	t:eq(state.headSelecting, true)
	t:eq(state.tailOver, true)
	t:eq(note.selecting, true)

	note:setPartInteractionState("head", false, false)
	t:eq(note.selecting, false)
end

return test
