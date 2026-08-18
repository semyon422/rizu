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
function Gameplay:new(settings, ui_config)
	Section.new(self, {
		name = "Gameplay",
		icon = Resources.sprites.icon_play,
		build = function(section)
			local keys = Settings.keys.gameplay
			local speed_type = settings:getChoice(keys.speed_type)
			local range = assert(ScrollSpeed.ranges[speed_type])
			local format = assert(ScrollSpeed.formats[speed_type])

			return {
				ControlFactory.segmentedChoice(settings, keys.speed_type, {
					name = "Scroll speed type",
					keywords = {"gameplay", "scroll", "speed", "osu"},
					format = formatScrollSpeedType,
					tip = "Choose the scale used by the scroll speed slider.",
					on_change = function()
						section:invalidate()
					end,
				}),
				ControlFactory.number(settings, keys.speed, {
					name = "Scroll speed",
					keywords = {"gameplay", "scroll", "speed"},
					tip = "Adjust how quickly notes move through the playfield.",
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
				ControlFactory.boolean(settings, keys.bga_image, {
					name = "Background images",
					keywords = {"gameplay", "background", "animation", "bga", "image"},
					tip = "Display BGA images in the gameplay background.",
				}),
				ControlFactory.boolean(settings, keys.bga_video, {
					name = "Background videos",
					keywords = {"gameplay", "background", "animation", "bga", "video"},
					tip = "Display BGA videos in the gameplay background.",
				}),
				ControlFactory.number(ui_config, ui_config.keys.gameplay_bga_brightness, {
					name = "BGA brightness",
					keywords = {"gameplay", "background", "animation", "bga", "brightness", "dim"},
					tip = "Adjust the brightness of gameplay BGA images and videos.",
					value_format = formatPercent,
				}),
			}
		end,
	})
end

return Gameplay
