local FakeFilesystem = require("fs.FakeFilesystem")
local Layout = require("ui.modals.config.sections.Layout")
local Resources = require("ui.Resources")
local Settings = require("rizu.config.Settings")
local View = require("gui.View")

local test = {}

---@return table sprites
local function createSprites()
	local sprite = {
		getHeight = function() return 20 end,
	}
	return {
		checkbox_body = sprite,
		checkbox_mark = sprite,
		form_element_cap_left = sprite,
		form_element_cap_middle = sprite,
		form_element_cap_right = sprite,
		icon_chevron = sprite,
		icon_monitor = sprite,
	}
end

---@param t testing.T
function test.exposes_fullscreen_mode_selector(t)
	local old_sprites = Resources.sprites
	local old_get_font = Resources.getFont
	Resources.sprites = createSprites()
	Resources.getFont = function()
		return {
			getHeight = function() return 16 end,
			getWidth = function(_, text) return #text * 8 end,
		}
	end

	local settings = Settings.createConfig(FakeFilesystem())
	local form = View()
	local popup_container = View()
	local controls = Layout(settings, form, popup_container):build()
	Resources.sprites = old_sprites
	Resources.getFont = old_get_font
	local fullscreen_type = controls[2] --[[@as ui.views.form.Dropdown]]

	t:eq(#controls, 2)
	t:eq(fullscreen_type.setting_name, "Fullscreen mode")
	t:eq(fullscreen_type.setting_key, Settings.keys.graphics.fullscreen_type)
	t:tdeq(fullscreen_type.options, {"desktop", "exclusive"})
	t:eq(fullscreen_type.format("desktop"), "Borderless desktop")
	t:eq(fullscreen_type.format("exclusive"), "Exclusive fullscreen")

	fullscreen_type:setValue("desktop", true)
	t:eq(settings:getChoice(Settings.keys.graphics.fullscreen_type), "desktop")
end

return test
