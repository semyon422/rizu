local FakeFilesystem = require("fs.FakeFilesystem")
local Localization = require("ui.localization.Localization")
local Offset = require("ui.modals.config.sections.Offset")
local Resources = require("ui.Resources")
local Settings = require("rizu.config.Settings")

local test = {}

---@param t testing.T
function test.exposes_chart_format_offsets(t)
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

	local settings = Settings.createConfig(FakeFilesystem())
	local controls = Offset(settings, Localization()):build()
	Resources.sprites = old_sprites
	Resources.getFont = old_get_font

	t:eq(#controls, 5)
	local expected = {
		osu = "osu! offset",
		qua = "Quaver offset",
		sm = "StepMania offset",
		ksh = "KSH offset",
	}
	for index, format in ipairs({"osu", "qua", "sm", "ksh"}) do
		local control = controls[index + 1] --[[@as ui.views.form.Slider]]
		local key = Settings.keys.gameplay.offset_format[format]
		t:eq(control.setting_key, key)
		t:eq(control.setting_name, expected[format])
		control:setValue(0.123, true)
		t:eq(settings:getNumber(key), 0.123)
	end
end

return test
