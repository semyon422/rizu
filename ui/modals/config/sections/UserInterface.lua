local ControlFactory = require("ui.modals.config.ControlFactory")
local Resources = require("ui.Resources")
local Section = require("ui.modals.config.Section")
local Settings = require("rizu.config.Settings")

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

---@param settings rizu.config.Config
function UserInterface:new(settings)
	Section.new(self, {
		name = "User Interface",
		icon = Resources.sprites.icon_layers,
		build = function()
			local keys = Settings.keys.select
			return {
				ControlFactory.boolean(settings, keys.chart_preview, {
					name = "Chart preview in Song Select",
					keywords = {"song select", "chart", "preview"},
					tip = "Show a preview of the selected chart in Song Select.",
				}),
				ControlFactory.segmentedChoice(settings, keys.diff_column, {
					name = "Displayed difficulty type",
					keywords = {"difficulty", "rating", "menus"},
					tip = "Choose the difficulty rating displayed in menus.",
					format = formatDifficulty,
				}),
			}
		end,
	})
end

return UserInterface
