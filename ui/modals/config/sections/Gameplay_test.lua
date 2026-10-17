local FakeFilesystem = require("fs.FakeFilesystem")
local Gameplay = require("ui.modals.config.sections.Gameplay")
local View = require("gui.View")
local Resources = require("ui.Resources")
local Settings = require("rizu.config.Settings")
local UiConfig = require("ui.UiConfig")
local Localization = require("ui.localization.Localization")

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
	local controls = Gameplay(settings, UiConfig(fs, "userdata/ui.json"), Localization()):build()
	Resources.sprites = old_sprites
	Resources.getFont = old_get_font

	for _, name in ipairs({"prepare", "play_pause", "pause_play", "play_retry", "pause_retry"}) do
		local time_key = Settings.keys.gameplay["time_" .. name]
		local found = false
		for _, control in ipairs(controls) do
			if control.setting_key == time_key then
				found = true
				t:eq(control.setting_name, Localization():get("settings.time_" .. name))
			end
		end
		t:eq(found, true)
	end

	local has_cursor_scale = false
	for _, control in ipairs(controls) do
		if control.setting_key == Settings.keys.gameplay.osu_cursor_scale then has_cursor_scale = true end
	end
	t:eq(has_cursor_scale, true)

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

---@param t testing.T
function test.cheat_controls_follow_enable_cheats(t)
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
	local section = Gameplay(settings, UiConfig(fs, "userdata/ui.json"), Localization(), nil, View())
	local keys = Settings.keys.gameplay

	---@param key string
	---@param controls ui.views.form.FormControl[]
	---@return boolean found
	local function has(key, controls)
		for _, control in ipairs(controls) do
			if control.setting_key == key then return true end
		end
		return false
	end

	local controls = section:build()
	t:eq(has(keys.tempo_factor, controls), false)
	t:eq(has(keys.swap_velocity_type, controls), false)

	settings:setBoolean(Settings.keys.misc.enable_cheats, true)
	controls = section:build()
	t:eq(has(keys.tempo_factor, controls), true)
	t:eq(has(keys.swap_velocity_type, controls), true)
	t:eq(has(keys.primary_tempo, controls), false)

	settings:setChoice(keys.tempo_factor, "primary")
	controls = section:build()
	t:eq(has(keys.primary_tempo, controls), true)

	Resources.sprites = old_sprites
	Resources.getFont = old_get_font
end

return test
