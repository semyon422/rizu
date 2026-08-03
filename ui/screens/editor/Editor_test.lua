local Editor = require("ui.screens.editor.Editor")
local EditorRhythmView = require("ui.screens.editor.EditorRhythmView")
local Inputs = require("gui.input.Inputs")
local ActionMap = require("gui.input.ActionMap")
local RhythmView = require("sphere.views.RhythmView")

local test = {}

---@param t testing.T
function test.creates_editor_rhythm_view_from_gameplay_notes_view(t)
	local transform = {}
	local game = {
		noteSkinModel = {
			noteSkin = {
				playField = {
					RhythmView({
						transform = transform,
						subscreen = "gameplay",
						isNotesView = true,
					}),
				},
			},
		},
	}
	local editor = Editor({game = game})

	editor:createRhythmView()

	t:eq(EditorRhythmView * editor.rhythm_view, true)
	t:eq(editor.rhythm_view.transform, transform)
	t:eq(editor.rhythm_view.game, game)
	t:eq(editor.rhythm_view.subscreen, "editor")
end

---@param t testing.T
function test.space_toggles_editor_playback(t)
	local calls = {}
	local context = {
		isPlaying = function()
			return #calls > 0
		end,
		play = function()
			calls[#calls + 1] = "play"
		end,
		pause = function()
			calls[#calls + 1] = "pause"
		end,
	}
	local game = {
		editorModel = {
			context = {
				getViewContext = function()
					return context
				end,
			},
		},
	}
	local editor = Editor({game = game})
	editor.editor_loaded = true

	local actions = ActionMap()
	actions:defineAction("editor.toggle_playback", {{key = "space"}})
	local inputs = Inputs()
	inputs:setActionMap(actions)
	local modifiers = {control = false, shift = false, alt = false, super = false}

	inputs:receive({name = "keypressed", "space"}, modifiers)
	editor:onHandleInputs(inputs)
	inputs:receive({name = "keyreleased", "space"}, modifiers)
	inputs:beginFrame(0, 0)
	inputs:receive({name = "keypressed", "space"}, modifiers)
	editor:onHandleInputs(inputs)
	t:tdeq(calls, {"play", "pause"})
end

return test
