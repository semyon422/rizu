local EditorSettingsService = require("rizu.editor.EditorSettingsService")
local Fraction = require("chart.core.Fraction")

local test = {}

---@param t testing.T
function test.settings_helpers(t)
	local editor = {
		speed = 0,
		snap = 999,
	}
	local configModel = {
		configs = {
			settings = {
				editor = editor,
				audio = {
					mode = "stereo",
				},
			},
		},
	}
	local service = EditorSettingsService()

	t:eq(service:getSettings(configModel, 192), editor)
	t:eq(editor.speed, 1)
	t:eq(editor.snap, 192)
	t:eq(service:getAudioSettings(configModel).mode, "stereo")

	service:setLogSpeed(editor, 10)
	t:eq(editor.speed, 2)
	t:eq(service:getLogSpeed(editor), 10)

	service:decSnap(editor, 192)
	t:eq(editor.snap, 96)
	service:incSnap(editor, 192)
	t:eq(editor.snap, 192)
	service:incSnap(editor, 192)
	t:eq(editor.snap, 192)
end

---@param t testing.T
function test.editor_context_helpers(t)
	local editor = {
		speed = 0,
		snap = 999,
	}
	local context = {
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
		maxSnap = 192,
	}
	local service = EditorSettingsService()

	t:eq(service:getEditorSettings(context), editor)
	t:eq(editor.speed, 1)
	t:eq(editor.snap, 192)
	t:eq(service:getEditorAudioSettings(context).mode, "stereo")

	service:setEditorLogSpeed(context, 10)
	t:eq(service:getEditorLogSpeed(context), 10)
	service:decEditorSnap(context)
	t:eq(editor.snap, 96)
	service:incEditorSnap(context)
	t:eq(editor.snap, 192)
	t:eq(service:getEditorSnap(context, Fraction(1, 2)), 2)

	local otherEditor = {
		speed = -1,
		snap = 999,
	}
	t:eq(service:normalizeContextEditorSettings(context, otherEditor), otherEditor)
	t:eq(otherEditor.speed, 1)
	t:eq(otherEditor.snap, 192)
end

---@param t testing.T
function test.get_snap(t)
	local service = EditorSettingsService()
	local editor = {
		speed = 1,
		snap = 4,
	}

	t:eq(service:getSnap(editor, 0), 1)
	t:eq(service:getSnap(editor, Fraction(1, 2)), 2)
end

return test
