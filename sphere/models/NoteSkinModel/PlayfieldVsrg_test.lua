local ChartPreviewRhythmView = require("sphere.views.SelectView.ChartPreviewRhythmView")
local PlayfieldVsrg = require("sphere.models.NoteSkinModel.PlayfieldVsrg")
local RhythmView = require("sphere.views.RhythmView")

local test = {}

---@param t testing.T
function test.add_notes_stays_shared_without_editor_views(t)
	local playfield = PlayfieldVsrg({
		unit = 1,
		align = "left",
	})

	playfield:addNotes()

	t:eq(#playfield, 2)
	t:eq(ChartPreviewRhythmView * playfield[1], true)
	t:eq(playfield[1].subscreen, "preview")
	t:eq(playfield[1].isNotesView, nil)
	t:eq(RhythmView * playfield[2], true)
	t:eq(playfield[2].subscreen, "gameplay")
	t:eq(playfield[2].isNotesView, true)
end

return test
