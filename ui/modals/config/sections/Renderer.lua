local ControlFactory = require("ui.modals.config.ControlFactory")
local Resources = require("ui.Resources")
local Section = require("ui.modals.config.Section")
local Settings = require("rizu.config.Settings")

---@class ui.modals.config.sections.Renderer : ui.modals.config.Section
---@operator call: ui.modals.config.sections.Renderer
local Renderer = Section + {}

---@param value number
---@return string formatted
local function formatFps(value)
	return ("%d FPS"):format(value)
end

---@param settings rizu.config.Config
---@param ui_config ui.UiConfig
---@param localization ui.localization.Localization
function Renderer:new(settings, ui_config, localization)
		local function formatVsync(value)
		return localization:get("settings.vsync_" .. value)
	end
	Section.new(self, {
		name = localization:get("settings.renderer"),
		icon = Resources.sprites.icon_image,
		build = function(section)
			local keys = Settings.keys.graphics
			local controls = {
				ControlFactory.boolean(settings, keys.unlimited_fps, {
					name = localization:get("settings.unlimited_fps"),
					keywords = {"performance", "frame rate", "limit"},
					tip = localization:get("settings.unlimited_fps_tip"),
					on_change = function()
						section:invalidate()
					end,
				}),
			}
			if not settings:getBoolean(keys.unlimited_fps) then
				controls[#controls + 1] = ControlFactory.number(settings, keys.fps, {
					name = localization:get("settings.fps_limit"),
					keywords = {"performance", "frame rate", "limit"},
					tip = localization:get("settings.fps_limit_tip"),
					min = 30,
					max = 1024,
					step = 1,
					value_format = formatFps,
				})
			end
			controls[#controls + 1] = ControlFactory.number(settings, keys.vsync, {
				name = "VSync",
				keywords = {"vertical sync", "tearing", "adaptive"},
				tip = localization:get("settings.vsync_tip"),
				value_format = formatVsync,
			})
			controls[#controls + 1] = ControlFactory.boolean(settings, keys.vsync_on_select, {
				name = localization:get("settings.vsync_outside_gameplay"),
				keywords = {"vsync", "vertical sync", "selection", "tearing"},
				tip = localization:get("settings.vsync_outside_gameplay_tip"),
			})
			controls[#controls + 1] = ControlFactory.boolean(ui_config, ui_config.keys.show_fps, {
				name = localization:get("settings.show_fps"),
				keywords = {"performance", "frame rate"},
				tip = localization:get("settings.show_fps_tip"),
			})
			return controls
		end,
	})
end

return Renderer
