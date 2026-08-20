local ControlFactory = require("ui.modals.config.ControlFactory")
local Resources = require("ui.Resources")
local Section = require("ui.modals.config.Section")
local Settings = require("rizu.config.Settings")

---@class ui.modals.config.sections.Layout : ui.modals.config.Section
---@operator call: ui.modals.config.sections.Layout
local Layout = Section + {}

local fullscreen_type_names = {
	desktop = "Borderless desktop",
	exclusive = "Exclusive fullscreen",
}

---@param value string
---@return string
local function formatFullscreenType(value)
	return assert(fullscreen_type_names[value], "unknown fullscreen type: " .. value)
end

---@param settings rizu.config.Config
---@param form ui.views.form.Form
---@param popup_container ui.views.PopupContainer
function Layout:new(settings, form, popup_container)
	Section.new(self, {
		name = "Layout",
		icon = Resources.sprites.icon_monitor,
		build = function()
			local keys = Settings.keys.graphics
			return {
				ControlFactory.boolean(settings, keys.fullscreen, {
					name = "Fullscreen",
					keywords = {"display", "window", "layout"},
					tip = "Display the game in fullscreen mode.",
				}),
				ControlFactory.choice(settings, keys.fullscreen_type, {
					form = form,
					popup_container = popup_container,
					name = "Fullscreen mode",
					keywords = {"display", "window", "layout", "borderless", "exclusive"},
					tip = "Choose borderless desktop or exclusive fullscreen mode.",
					format = formatFullscreenType,
				}),
			}
		end,
	})
end

return Layout
