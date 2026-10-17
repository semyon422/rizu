local FakeFilesystem = require("fs.FakeFilesystem")
local Localization = require("ui.localization.Localization")
local Other = require("ui.modals.config.sections.Other")
local Resources = require("ui.Resources")
local Settings = require("rizu.config.Settings")
local UiConfig = require("ui.UiConfig")

local test = {}

---@param t testing.T
function test.disabling_cheats_resets_cheat_settings(t)
	local old_sprites = Resources.sprites
	local old_get_font = Resources.getFont
	local sprite = {
		getWidth = function() return 10 end,
		getHeight = function() return 20 end,
	}
	Resources.sprites = setmetatable({}, {__index = function() return sprite end})
	Resources.getFont = function()
		return {
			getHeight = function() return 16 end,
			getWidth = function(_, text) return #text * 8 end,
			getWrap = function(_, text) return #text * 8, {text} end,
		}
	end

	local fs = FakeFilesystem()
	fs:createDirectory("userdata")
	local settings = Settings.createConfig(fs)
	local section = Other(settings, UiConfig(fs, "userdata/ui.json"), Localization())
	local invalidated = 0
	section:setInvalidator(function() invalidated = invalidated + 1 end)
	local controls = section:build()
	Resources.sprites = old_sprites
	Resources.getFont = old_get_font

	local cheats_key = Settings.keys.misc.enable_cheats
	local gameplay = Settings.keys.gameplay
	local checkbox
	for _, control in ipairs(controls) do
		if control.setting_key == cheats_key then
			checkbox = control --[[@as ui.views.form.Checkbox]]
		end
	end
	assert(checkbox)

	checkbox:activate()
	t:eq(settings:getBoolean(cheats_key), true)
	t:eq(invalidated, 1)
	settings:setChoice(gameplay.tempo_factor, "primary")
	settings:setNumber(gameplay.primary_tempo, 180)
	settings:setBoolean(gameplay.swap_velocity_type, true)

	checkbox:activate()
	t:eq(settings:getBoolean(cheats_key), false)
	t:eq(invalidated, 2)
	t:eq(settings:getChoice(gameplay.tempo_factor), "average")
	t:eq(settings:getNumber(gameplay.primary_tempo), 120)
	t:eq(settings:getBoolean(gameplay.swap_velocity_type), false)
end

return test
