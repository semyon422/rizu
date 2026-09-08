local ControlFactory = require("ui.modals.config.ControlFactory")
local GameplayViewportPreview = require("ui.modals.config.GameplayViewportPreview")
local Resources = require("ui.Resources")
local Section = require("ui.modals.config.Section")

---@class ui.modals.config.sections.GameplayViewport : ui.modals.config.Section
---@operator call: ui.modals.config.sections.GameplayViewport
local GameplayViewport = Section + {}

---@param value number
---@return string formatted
local function formatPercent(value)
	return ("%d%%"):format(math.floor(value * 100 + 0.5))
end

---@param ui_config ui.UiConfig
---@param localization ui.localization.Localization
function GameplayViewport:new(ui_config, localization)
	local keys = ui_config.keys
		Section.new(self, {
		name = localization:get("settings.gameplay_viewport"),
		icon = Resources.sprites.icon_camera,
		build = function()
			return {
				GameplayViewportPreview(ui_config, localization:get("settings.final_resolution")),
				ControlFactory.number(ui_config, keys.gameplay_viewport_x, {
					name = localization:get("settings.horizontal_position"),
					keywords = {"gameplay", "viewport", "alignment", "accessibility"},
					tip = localization:get("settings.horizontal_position_tip"),
					min = 0,
					max = 1,
					step = 0.01,
					value_format = formatPercent,
				}),
				ControlFactory.number(ui_config, keys.gameplay_viewport_y, {
					name = localization:get("settings.vertical_position"),
					keywords = {"gameplay", "viewport", "alignment", "accessibility"},
					tip = localization:get("settings.vertical_position_tip"),
					min = 0,
					max = 1,
					step = 0.01,
					value_format = formatPercent,
				}),
				ControlFactory.number(ui_config, keys.gameplay_viewport_sx, {
					name = localization:get("settings.width"),
					keywords = {"gameplay", "viewport", "scale", "size", "accessibility"},
					tip = localization:get("settings.width_tip"),
					min = 0.25,
					max = 1,
					step = 0.01,
					value_format = formatPercent,
				}),
				ControlFactory.number(ui_config, keys.gameplay_viewport_sy, {
					name = localization:get("settings.height"),
					keywords = {"gameplay", "viewport", "scale", "size", "accessibility"},
					tip = localization:get("settings.height_tip"),
					min = 0.25,
					max = 1,
					step = 0.01,
					value_format = formatPercent,
				}),
			}
		end,
	})
end

return GameplayViewport
