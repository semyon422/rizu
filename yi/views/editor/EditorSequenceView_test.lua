local EditorRhythmView = require("yi.views.editor.EditorRhythmView")
local EditorSequenceView = require("yi.views.editor.EditorSequenceView")
local RhythmView = require("sphere.views.RhythmView")

local test = {}

---@param t testing.T
function test.injects_editor_rhythm_view_from_gameplay_notes_view(t)
	local oldLove = love
	love = {
		graphics = {
			getDimensions = function()
				return 1920, 1080
			end,
		},
	}

	local screen = {}
	local sequenceView = EditorSequenceView(screen)
	love = oldLove

	local transform = {}
	local cameraView = {}
	local gameplayNotesView = RhythmView({
		transform = transform,
		isNotesView = true,
		subscreen = "gameplay",
	})
	local gameplayLightingView = RhythmView({
		transform = {},
		mode = "lighting",
		subscreen = "gameplay",
	})

	sequenceView:setPlayfield({
		cameraView,
		gameplayNotesView,
		gameplayLightingView,
	})

	t:eq(sequenceView.missingEditorNotesView, false)
	t:eq(sequenceView.sequenceViews[1], cameraView)
	t:eq(sequenceView.sequenceViews[2], gameplayNotesView)
	t:eq(EditorRhythmView * sequenceView.sequenceViews[3], true)
	t:eq(sequenceView.sequenceViews[3].transform, transform)
	t:eq(sequenceView.sequenceViews[3].subscreen, "editor")
	t:eq(sequenceView.sequenceViews[4], gameplayLightingView)
	t:eq(sequenceView.sequenceViews[5], nil)
end

---@param t testing.T
function test.marks_missing_editor_notes_view_when_skin_has_no_notes_view(t)
	local oldLove = love
	love = {
		graphics = {
			getDimensions = function()
				return 1920, 1080
			end,
		},
	}

	local screen = {}
	local sequenceView = EditorSequenceView(screen)
	love = oldLove

	local gameplayLightingView = RhythmView({
		transform = {},
		mode = "lighting",
		subscreen = "gameplay",
	})

	sequenceView:setPlayfield({
		gameplayLightingView,
	})

	t:eq(sequenceView.missingEditorNotesView, true)
	t:eq(sequenceView.sequenceViews[1], gameplayLightingView)
	t:eq(sequenceView.sequenceViews[2], nil)
end

return test
