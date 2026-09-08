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
---@param localization ui.localization.Localization
function UserInterface:new(settings, localization)
		Section.new(self, {
		name = localization:get("settings.user_interface"),
		icon = Resources.sprites.icon_layers,
		build = function()
			local keys = Settings.keys.select
			return {
				ControlFactory.boolean(settings, keys.chart_preview, {
					name = localization:get("settings.chart_preview"),
					keywords = {"song select", "chart", "preview"},
					tip = localization:get("settings.chart_preview_tip"),
				}),
				ControlFactory.segmentedChoice(settings, keys.diff_column, {
					name = localization:get("settings.difficulty_type"),
					keywords = {"difficulty", "rating", "menus"},
					tip = localization:get("settings.difficulty_type_tip"),
					format = formatDifficulty,
				}),
			}
		end,
	})
end

return UserInterface
