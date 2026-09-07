local FakeFilesystem = require("fs.FakeFilesystem")
local Gameplay = require("ui.modals.config.sections.Gameplay")
local Resources = require("ui.Resources")
local Settings = require("rizu.config.Settings")
local UiConfig = require("ui.UiConfig")

local test = {}

---@param t testing.T
function test.auto_keysound_binds_gameplay_setting(t)
	local old_sprites = Resources.sprites
	local old_get_font = Resources.getFont
	local sprite = {
		getWidth = function() return 10 end,
		getHeight = function() return 20 end,
	}
	Resources.sprites = {
		checkbox_body = sprite,
		checkbox_mark = sprite,
		slider_line_left = sprite,
		slider_line_middle = sprite,
		slider_line_right = sprite,
		slider_thumb = sprite,
		segmented_bg_left = sprite,
		segmented_bg_middle = sprite,
		segmented_bg_right = sprite,
		icon_play = sprite,
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
	local controls = Gameplay(settings, UiConfig(fs, "userdata/ui.json")):build()
	Resources.sprites = old_sprites
	Resources.getFont = old_get_font

	local key = Settings.keys.gameplay.auto_key_sound
	---@type ui.views.form.Checkbox?
	local checkbox
	for _, control in ipairs(controls) do
		if control.setting_key == key then
			checkbox = control --[[@as ui.views.form.Checkbox]]
		end
	end
	assert(checkbox)
	t:eq(checkbox.setting_name, "Auto keysound")
	t:eq(settings:getBoolean(key), false)
	checkbox:activate()
	t:eq(settings:getBoolean(key), true)
	t:eq(settings:save(), true)
	local restored = Settings.createConfig(fs)
	t:eq(restored:load(), true)
	t:eq(restored:getBoolean(key), true)
	checkbox:activate()
	t:eq(settings:getBoolean(key), false)
end

return test
