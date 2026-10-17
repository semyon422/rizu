local FakeFilesystem = require("fs.FakeFilesystem")
local Localization = require("ui.localization.Localization")
local Offset = require("ui.modals.config.sections.Offset")
local Resources = require("ui.Resources")
local Settings = require("rizu.config.Settings")

local test = {}

---@param t testing.T
function test.universal_and_format_controls_bind_only_audio_settings(t)
	local old_sprites = Resources.sprites
	local old_get_font = Resources.getFont
	local sprite = {
		getWidth = function() return 10 end,
		getHeight = function() return 20 end,
	}
	Resources.sprites = {
		slider_line_left = sprite,
		slider_line_middle = sprite,
		slider_line_right = sprite,
		slider_thumb = sprite,
		icon_metronome = sprite,
	}
	Resources.getFont = function()
		return {
			getHeight = function() return 16 end,
			getWidth = function(_, text) return #text * 8 end,
		}
	end
	local fs = FakeFilesystem()
	fs:createDirectory("userdata")
	local settings = Settings.createConfig(fs)
	local ok, controls = pcall(function()
		return Offset(settings, Localization()):build()
	end)
	Resources.sprites = old_sprites
	Resources.getFont = old_get_font
	t:assert(ok, controls)
	---@cast controls ui.views.form.Slider[]
	t:eq(#controls, 5)
	local keys = Settings.keys.gameplay
	t:eq(controls[1].setting_key, keys.offset_audio_mode.bass_sample)
	t:eq(controls[1].setting_name, "Universal offset")
	controls[1]:setValue(0.037, true)
	t:eq(settings:getNumber(keys.offset_audio_mode.bass_sample), 0.037)
	t:eq(settings:getNumber(keys.offset_audio_mode.bass_fx_tempo), 0.037)

	for index, format in ipairs({"osu", "quaver", "stepmania", "ksm"}) do
		local control = controls[index + 1]
		t:eq(control.setting_key, keys.offset_format[format])
		control:setValue(-0.123, true)
		t:eq(settings:getNumber(keys.offset_format[format]), -0.123)
	end
	t:eq(settings:save(), true)
	local restored = Settings.createConfig(fs)
	t:eq(restored:load(), true)
	t:eq(restored:getNumber(keys.offset_audio_mode.bass_fx_tempo), 0.037)
	t:eq(restored:getNumber(keys.offset_format.quaver), -0.123)
end

return test
