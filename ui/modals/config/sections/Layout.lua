local ControlFactory = require("ui.modals.config.ControlFactory")
local Resources = require("ui.Resources")
local Section = require("ui.modals.config.Section")
local Settings = require("rizu.config.Settings")

---@class ui.modals.config.sections.Layout : ui.modals.config.Section
---@operator call: ui.modals.config.sections.Layout
local Layout = Section + {}

---@param settings rizu.config.Config
function Layout:new(settings)
	Section.new(self, {
		name = "Layout",
		icon = Resources.sprites.icon_monitor,
		build = function()
			return {
				ControlFactory.boolean(settings, Settings.keys.graphics.fullscreen, {
					name = "Fullscreen",
					keywords = {"display", "window", "layout"},
					tip = "Display the game in fullscreen mode.",
				}),
			}
		end,
	})
end

return Layout
