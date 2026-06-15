local RhythmView = require("sphere.views.RhythmView")

---@class rizu.editor.EditorRhythmView: sphere.RhythmView
---@operator call: rizu.editor.EditorRhythmView
local EditorRhythmView = RhythmView + {}

---@param f function
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
