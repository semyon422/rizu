local RhythmView = require("sphere.views.RhythmView")

---@class ui.screens.editor.EditorRhythmView: sphere.RhythmView
---@operator call: ui.screens.editor.EditorRhythmView
local EditorRhythmView = RhythmView + {}

---@param f fun(view: ui.screens.editor.EditorRhythmView, note: rizu.editor.EditorNote)
function EditorRhythmView:processNotes(f)
	local editorModel = self.game.editorModel
	for _, note in ipairs(editorModel.visualEngine.notes) do
		f(self, note)
	end
	for _, note in ipairs(editorModel.noteService:getGrabbedNotes()) do
		f(self, note)
	end
end

return EditorRhythmView
