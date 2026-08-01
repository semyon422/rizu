local ControlFactory = require("ui.modals.config.ControlFactory")
local Resources = require("ui.Resources")
local Section = require("ui.modals.config.Section")

---@class ui.modals.config.sections.Interface : ui.modals.config.Section
---@operator call: ui.modals.config.sections.Interface
local Interface = Section + {}

---@param ui_config ui.UiConfig
function Interface:new(ui_config)
	Section.new(self, {
		name = "Interface",
		icon = Resources.sprites.icon_gear,
		build = function()
			return {
				ControlFactory.boolean(ui_config, ui_config.keys.show_fps, {
					name = "Show FPS",
					keywords = {"performance", "frame rate"},
					tip = "Display frame timing information.",
				}),
			}
		end,
	})
end

return Interface
