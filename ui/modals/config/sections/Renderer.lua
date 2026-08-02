local ControlFactory = require("ui.modals.config.ControlFactory")
local Resources = require("ui.Resources")
local Section = require("ui.modals.config.Section")

---@class ui.modals.config.sections.Renderer : ui.modals.config.Section
---@operator call: ui.modals.config.sections.Renderer
local Renderer = Section + {}

---@param value number
---@return string formatted
local function formatFps(value)
	return ("%d FPS"):format(value)
end

local vsync_values = {
	[-1] = "Adaptive",
	[0] = "Off",
	[1] = "On"
}

---@param value integer
---@return string formatted
local function formatVsync(value)
	return vsync_values[value]
end

---@param settings sphere.SettingsConfig
---@param ui_config ui.UiConfig
function Renderer:new(settings, ui_config)
	Section.new(self, {
		name = "Renderer",
		icon = Resources.sprites.icon_image,
		build = function(section)
			local controls = {
				ControlFactory.legacyBoolean(settings, {"graphics", "unlimited_fps"}, {
					name = "Unlimited FPS",
					keywords = {"performance", "frame rate", "limit"},
					tip = "Disable the renderer frame-rate limit.",
					on_change = function()
						section:invalidate()
					end,
				}),
			}
			if not settings.graphics.unlimited_fps then
				controls[#controls + 1] = ControlFactory.legacyNumber(settings, {"graphics", "fps"}, {
					name = "FPS limit",
					keywords = {"performance", "frame rate", "limit"},
					tip = "Set the renderer frame-rate limit when unlimited FPS is disabled.",
					min = 30,
					max = 1024,
					step = 1,
					value_format = formatFps,
				})
			end
			controls[#controls + 1] = ControlFactory.legacyChoice(settings, {"graphics", "mode", "flags", "vsync"}, {
				name = "VSync",
				keywords = {"vertical sync", "tearing", "adaptive"},
				tip = "Synchronize frame presentation with the display refresh rate.",
				options = {-1, 0, 1},
				format = formatVsync,
			})
			controls[#controls + 1] = ControlFactory.boolean(ui_config, ui_config.keys.show_fps, {
				name = "Show FPS",
				keywords = {"performance", "frame rate"},
				tip = "Display frame timing information.",
			})
			return controls
		end,
	})
end

return Renderer
