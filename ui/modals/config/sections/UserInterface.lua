local ControlFactory = require("ui.modals.config.ControlFactory")
local Resources = require("ui.Resources")
local Section = require("ui.modals.config.Section")
local Settings = require("rizu.config.Settings")
local UiConfig = require("ui.UiConfig")

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

---@param value string
---@return string formatted
local function formatLanguage(value)
	return ({
		en = "English",
		ru = "Русский",
		es = "Español (AI translation)",
	})[value]
end

---@param settings rizu.config.Config
---@param ui_config ui.UiConfig
---@param localization ui.localization.Localization
---@param form ui.views.form.Form
---@param popup_container ui.views.PopupContainer
---@param on_language_change fun()
function UserInterface:new(settings, ui_config, localization, form, popup_container, on_language_change)
	Section.new(self, {
		name = localization:get("settings.user_interface"),
		icon = Resources.sprites.icon_layers,
		build = function()
			local select_keys = Settings.keys.select
			return {
				ControlFactory.choice(ui_config, UiConfig.keys.language, {
					name = localization:get("settings.language"),
					keywords = {"language", "locale"},
					tip = localization:get("settings.language_tip"),
					format = formatLanguage,
					form = form,
					popup_container = popup_container,
					on_change = on_language_change,
				}),
				ControlFactory.boolean(settings, select_keys.chart_preview, {
					name = localization:get("settings.chart_preview"),
					keywords = {"song select", "chart", "preview"},
					tip = localization:get("settings.chart_preview_tip"),
				}),
				ControlFactory.segmentedChoice(settings, select_keys.diff_column, {
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
