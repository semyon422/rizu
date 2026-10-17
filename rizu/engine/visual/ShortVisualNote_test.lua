local ShortVisualNote = require("rizu.engine.visual.ShortVisualNote")
local VisualInfo = require("rizu.engine.visual.VisualInfo")
local LinkedNote = require("chart.model.notes.LinkedNote")
local Note = require("chart.model.notes.Note")
local VisualPoint = require("chart.model.visual.VisualPoint")
local Point = require("chart.model.tp.Point")

local test = {}

---@param t testing.T
function test.all(t)
	local linked_note = LinkedNote(Note(VisualPoint(Point(1)), "key1", "tap", 0))
	local visual_info = VisualInfo()
	local visual_note = ShortVisualNote(linked_note, visual_info)

	visual_note:update()
	t:eq(visual_note.start_dt, -1)

	visual_info.time = 0.25
	visual_note:update()
	t:eq(visual_note.start_dt, -0.75)

	visual_info.rate = 2 -- increase play speed
	visual_note:update()
	t:eq(visual_note.start_dt, -1.5)
end

return test
