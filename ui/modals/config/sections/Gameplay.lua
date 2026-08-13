local ControlFactory = require("ui.modals.config.ControlFactory")
local Resources = require("ui.Resources")
local Section = require("ui.modals.config.Section")
local SpeedModel = require("sphere.models.SpeedModel")

---@class ui.modals.config.sections.Gameplay : ui.modals.config.Section
---@operator call: ui.modals.config.sections.Gameplay
local Gameplay = Section + {}

---@param settings sphere.SettingsConfig
---@param speed_model sphere.SpeedModel
function Gameplay:new(settings, speed_model)
	Section.new(self, {
		name = "Gameplay",
		icon = Resources.sprites.icon_play,
		build = function(section)
			local speed_type = settings.gameplay.speedType
			local range = assert(SpeedModel.range[speed_type])
			local format = assert(SpeedModel.format[speed_type])

			return {
				ControlFactory.legacyChoice(settings, {"gameplay", "speedType"}, {
					name = "Scroll speed type",
					keywords = {"gameplay", "scroll", "speed", "osu"},
					tip = "Choose the scale used by the scroll speed slider.",
					options = SpeedModel.types,
					on_change = function()
						section:invalidate()
					end,
				}),
				ControlFactory.legacyNumber(settings, {"gameplay", "speed"}, {
					name = "Scroll speed",
					keywords = {"gameplay", "scroll", "speed"},
					tip = "Adjust how quickly notes move through the playfield.",
					min = range[1],
					max = range[2],
					step = range[3],
					from_storage = function()
						return speed_model:get()
					end,
					to_storage = function(value)
						speed_model:set(value)
						return settings.gameplay.speed
					end,
					value_format = function(value)
						return format:format(value)
					end,
				}),
			}
		end,
	})
end

return Gameplay
