local ControlFactory = require("ui.modals.config.ControlFactory")
local Resources = require("ui.Resources")
local Section = require("ui.modals.config.Section")

---@class ui.modals.config.sections.UserInterface : ui.modals.config.Section
---@operator call: ui.modals.config.sections.UserInterface
local UserInterface = Section + {}

---@param value string
---@return string formatted
local function formatDifficulty(value)
	return ({
		enps_diff = "ENPS",
		osu_diff = "osu!",
		msd_diff = "MSD",
		user_diff = "User",
	})[value]
end

---@param settings sphere.SettingsConfig
function UserInterface:new(settings)
	Section.new(self, {
		name = "User Interface",
		icon = Resources.sprites.icon_layers,
		build = function()
			return {
				ControlFactory.legacyBoolean(settings, {"select", "chart_preview"}, {
					name = "Chart preview in Song Select",
					keywords = {"song select", "chart", "preview"},
					tip = "Show a preview of the selected chart in Song Select.",
				}),
				ControlFactory.legacyChoice(settings, {"select", "diff_column"}, {
					name = "Displayed difficulty type",
					keywords = {"difficulty", "rating", "menus"},
					tip = "Choose the difficulty rating displayed in menus.",
					options = {"enps_diff", "osu_diff", "msd_diff", "user_diff"},
					format = formatDifficulty,
				}),
			}
		end,
	})
end

return UserInterface
