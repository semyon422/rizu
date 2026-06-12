local EditorSettingsService = require("rizu.editor.EditorSettingsService")
local Fraction = require("chart.core.Fraction")

local test = {}

---@param t testing.T
function test.settings_helpers(t)
	local editor = {
		speed = 0,
		snap = 999,
	}
	local editorModel = {
		max_snap = 192,
		configModel = {
			configs = {
				settings = {
					editor = editor,
					audio = {
						mode = "stereo",
					},
				},
			},
		},
	}
	local service = EditorSettingsService()

	t:eq(service:getSettings(editorModel), editor)
	t:eq(editor.speed, 1)
	t:eq(editor.snap, 192)
	t:eq(service:getAudioSettings(editorModel).mode, "stereo")

	service:setLogSpeed(editorModel, 10)
	t:eq(editor.speed, 2)
	t:eq(service:getLogSpeed(editorModel), 10)

	service:decSnap(editorModel)
	t:eq(editor.snap, 96)
	service:incSnap(editorModel)
	t:eq(editor.snap, 192)
	service:incSnap(editorModel)
	t:eq(editor.snap, 192)
end

---@param t testing.T
function test.get_snap(t)
	local service = EditorSettingsService()
	local editorModel = {
		max_snap = 192,
		configModel = {
			configs = {
				settings = {
					editor = {
						speed = 1,
						snap = 4,
					},
				},
			},
		},
	}

	t:eq(service:getSnap(editorModel, 0), 1)
	t:eq(service:getSnap(editorModel, Fraction(1, 2)), 2)
end

return test
