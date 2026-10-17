local Notes = require("chart.model.notes.Notes")
local Note = require("chart.model.notes.Note")

local test = {}

function test.long_note(t)
	local notes = Notes()
	notes:insert(Note(1, "key", "hold", 1))
	notes:insert(Note(2, "key", "hold", -1))
	t:assert(notes:isValid())
end

function test.long_note_2_types(t)
	local notes = Notes()
	notes:insert(Note(1, "key", "hold", 1))
	notes:insert(Note(2, "key", "hold2", 1))
	notes:insert(Note(3, "key", "hold", -1))
	notes:insert(Note(4, "key", "hold2", -1))
	t:assert(notes:isValid())
end

function test.error_on_non_zero_weight(t)
	local notes = Notes()
	notes:insert(Note(1, "key", "tap", 1))
	t:assert(not notes:isValid())
end

function test.link(t)
	local notes = Notes()
	notes:insert(Note(1, "key", "hold", 1))
	notes:insert(Note(2, "key", "hold", 1))
	notes:insert(Note(3, "key", "tap", 0))
	notes:insert(Note(4, "key", "hold", -1))
	notes:insert(Note(5, "key", "hold", -1))

	local lnotes = notes:link(notes.notes)
	t:eq(#lnotes, 3)

	t:assert(lnotes[1]:isLong())
	t:eq(lnotes[1]:getType(), "hold")

	t:assert(lnotes[2]:isLong())
	t:eq(lnotes[2]:getType(), "hold")

	t:assert(lnotes[3]:isShort())
	t:eq(lnotes[3]:getType(), "tap")
end

function test.mutated_invalid(t)
	local notes = Notes()

	local note = Note(1, "key1", "tap", 0)
	notes:insert(note)

	t:assert(notes:isValid())

	note.visualPoint, note.column = 2, "key1"
	t:assert(not notes:isValid())

	note.visualPoint, note.column = 1, "key2"
	t:assert(not notes:isValid())

	note.visualPoint, note.column = 2, "key2"
	t:assert(not notes:isValid())

	note.visualPoint, note.column = 1, "key1"
	t:assert(notes:isValid())
end

return test
