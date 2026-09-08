local ControlFactory = require("ui.modals.config.ControlFactory")
local Resources = require("ui.Resources")
local Section = require("ui.modals.config.Section")
local ScrollSpeed = require("rizu.gameplay.ScrollSpeed")
local Settings = require("rizu.config.Settings")

---@class ui.modals.config.sections.Gameplay : ui.modals.config.Section
---@operator call: ui.modals.config.sections.Gameplay
local Gameplay = Section + {}

---@param value string
---@return string formatted
local function formatScrollSpeedType(value)
	return ({
		default = "Rizu",
		osu = "osu!",
	})[value]
end

---@param value number
---@return string formatted
local function formatPercent(value)
	return ("%d%%"):format(math.floor(value * 100 + 0.5))
end

---@param settings rizu.config.Config
---@param ui_config ui.UiConfig
---@param localization ui.localization.Localization
function Gameplay:new(settings, ui_config, localization)
		Section.new(self, {
		name = localization:get("settings.gameplay"),
		icon = Resources.sprites.icon_play,
		build = function(section)
			local keys = Settings.keys.gameplay
			local speed_type = settings:getChoice(keys.speed_type)
			local range = assert(ScrollSpeed.ranges[speed_type])
			local format = assert(ScrollSpeed.formats[speed_type])

			return {
				ControlFactory.segmentedChoice(settings, keys.speed_type, {
					name = localization:get("settings.scroll_speed_type"),
					keywords = {"gameplay", "scroll", "speed", "osu"},
					format = formatScrollSpeedType,
					tip = localization:get("settings.scroll_speed_type_tip"),
					on_change = function()
						section:invalidate()
					end,
				}),
				ControlFactory.number(settings, keys.speed, {
					name = localization:get("settings.scroll_speed"),
					keywords = {"gameplay", "scroll", "speed"},
					tip = localization:get("settings.scroll_speed_tip"),
					min = range[1],
					max = range[2],
					step = range[3],
					from_storage = function(value)
						return ScrollSpeed.toDisplay(speed_type, value)
					end,
					to_storage = function(value)
						return ScrollSpeed.toCanonical(speed_type, value)
					end,
					value_format = function(value)
						return format:format(value)
					end,
				}),
				ControlFactory.boolean(settings, keys.auto_key_sound, {
					name = localization:get("settings.auto_keysound"),
					keywords = {"gameplay", "audio", "auto", "keysound"},
					tip = localization:get("settings.auto_keysound_tip"),
				}),
				ControlFactory.boolean(settings, keys.bga_image, {
					name = localization:get("settings.background_images"),
					keywords = {"gameplay", "background", "animation", "bga", "image"},
					tip = localization:get("settings.background_images_tip"),
				}),
				ControlFactory.boolean(settings, keys.bga_video, {
					name = localization:get("settings.background_videos"),
					keywords = {"gameplay", "background", "animation", "bga", "video"},
					tip = localization:get("settings.background_videos_tip"),
				}),
				ControlFactory.number(ui_config, ui_config.keys.gameplay_bga_brightness, {
					name = localization:get("settings.bga_brightness"),
					keywords = {"gameplay", "background", "animation", "bga", "brightness", "dim"},
					tip = localization:get("settings.bga_brightness_tip"),
					value_format = formatPercent,
				}),
			}
		end,
	})
end

return Gameplay
