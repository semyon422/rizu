local ControlFactory = require("ui.modals.config.ControlFactory")
local Resources = require("ui.Resources")
local Section = require("ui.modals.config.Section")
local Settings = require("rizu.config.Settings")

---@class ui.modals.config.sections.Layout : ui.modals.config.Section
---@operator call: ui.modals.config.sections.Layout
local Layout = Section + {}

---@param settings rizu.config.Config
---@param form ui.views.form.Form
---@param popup_container ui.views.PopupContainer
---@param localization ui.localization.Localization
function Layout:new(settings, form, popup_container, localization)
		local function formatFullscreenType(value)
		return localization:get("settings.fullscreen_type_" .. value)
	end
	Section.new(self, {
		name = localization:get("settings.layout"),
		icon = Resources.sprites.icon_monitor,
		build = function()
			local keys = Settings.keys.graphics
			return {
				ControlFactory.boolean(settings, keys.fullscreen, {
					name = localization:get("settings.fullscreen"),
					keywords = {"display", "window", "layout"},
					tip = localization:get("settings.fullscreen_tip"),
				}),
				ControlFactory.choice(settings, keys.fullscreen_type, {
					form = form,
					popup_container = popup_container,
					name = localization:get("settings.fullscreen_mode"),
					keywords = {"display", "window", "layout", "borderless", "exclusive"},
					tip = localization:get("settings.fullscreen_mode_tip"),
					format = formatFullscreenType,
				}),
			}
		end,
	})
end

return Layout
