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
function GameplayViewport:new(ui_config)
	local keys = ui_config.keys
	Section.new(self, {
		name = "Gameplay Viewport",
		icon = Resources.sprites.icon_camera,
		build = function()
			return {
				GameplayViewportPreview(ui_config),
				ControlFactory.number(ui_config, keys.gameplay_viewport_x, {
					name = "Horizontal position",
					keywords = {"gameplay", "viewport", "alignment", "accessibility"},
					tip = "Position the gameplay area horizontally within the screen.",
					min = 0,
					max = 1,
					step = 0.01,
					value_format = formatPercent,
				}),
				ControlFactory.number(ui_config, keys.gameplay_viewport_y, {
					name = "Vertical position",
					keywords = {"gameplay", "viewport", "alignment", "accessibility"},
					tip = "Position the gameplay area vertically within the screen.",
					min = 0,
					max = 1,
					step = 0.01,
					value_format = formatPercent,
				}),
				ControlFactory.number(ui_config, keys.gameplay_viewport_sx, {
					name = "Width",
					keywords = {"gameplay", "viewport", "scale", "size", "accessibility"},
					tip = "Scale down the gameplay area's width to make notes easier to see.",
					min = 0.25,
					max = 1,
					step = 0.01,
					value_format = formatPercent,
				}),
				ControlFactory.number(ui_config, keys.gameplay_viewport_sy, {
					name = "Height",
					keywords = {"gameplay", "viewport", "scale", "size", "accessibility"},
					tip = "Scale down the gameplay area's height to make notes easier to see.",
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
