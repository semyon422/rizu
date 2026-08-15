local EditorSettingsService = require("rizu.editor.settings.EditorSettingsService")
local FakeFilesystem = require("fs.FakeFilesystem")
local Fraction = require("chart.core.Fraction")
local Settings = require("rizu.config.Settings")

local test = {}

---@return rizu.config.Config
local function createSettings()
	return Settings.createConfig(FakeFilesystem())
end

---@param t testing.T
function test.settings_helpers(t)
	local settings = createSettings()
	local service = EditorSettingsService()
	local editor = service:getSettings(settings, 192)

	t:eq(editor.speed, 1)
	t:eq(editor.snap, 1)
	editor.speed = 2
	editor.snap = 192
	t:eq(settings:getNumber(Settings.keys.editor.speed), 2)
	t:eq(settings:getNumber(Settings.keys.editor.snap), 192)

	service:setLogSpeed(editor, 10)
	t:eq(editor.speed, 2)
	t:eq(service:getLogSpeed(editor), 10)

	service:decSnap(editor, 192)
	t:eq(editor.snap, 96)
	service:incSnap(editor, 192)
	t:eq(editor.snap, 192)
	service:incSnap(editor, 192)
	t:eq(editor.snap, 192)

	local audio = service:getAudioSettings(settings)
	audio.volume.master = 0.5
	audio.mode.primary = "bass_sample"
	t:eq(settings:getNumber(Settings.keys.audio.volume_master), 0.5)
	t:eq(settings:getChoice(Settings.keys.audio.mode_primary), "bass_sample")
end

---@param t testing.T
function test.editor_context_helpers(t)
	local settings = createSettings()
	local context = {
		getConfig = function() return settings end,
		getMaxSnap = function() return 192 end,
	}
	local service = EditorSettingsService()
	local editor = service:getEditorSettings(context)

	editor.snap = 192
	service:setEditorLogSpeed(context, 10)
	t:eq(service:getEditorLogSpeed(context), 10)
	service:decEditorSnap(context)
	t:eq(editor.snap, 96)
	service:incEditorSnap(context)
	t:eq(editor.snap, 192)
	t:eq(service:getEditorSnap(context, Fraction(1, 2)), 2)
end

---@param t testing.T
function test.get_snap(t)
	local service = EditorSettingsService()
	local editor = {speed = 1, snap = 4}
	t:eq(service:getSnap(editor, 0), 1)
	t:eq(service:getSnap(editor, Fraction(1, 2)), 2)
end

return test
