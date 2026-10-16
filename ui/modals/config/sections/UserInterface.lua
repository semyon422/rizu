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

---@param value string
---@param app rizu.api.App
---@return string formatted
local function formatUserInterface(value, app)
	return app:getUserInterfaceDisplayName(value) or value
end

---@param settings rizu.config.Config
---@param ui_config ui.UiConfig
---@param localization ui.localization.Localization
---@param form ui.views.form.Form
---@param popup_container ui.views.PopupContainer
---@param on_language_change fun()
---@param app rizu.api.App
---@param on_diff_column_change fun()
function UserInterface:new(settings, ui_config, localization, form, popup_container, on_language_change, app, on_diff_column_change)
	Section.new(self, {
		name = localization:get("settings.user_interface"),
		icon = Resources.sprites.icon_layers,
		build = function()
			local select_keys = Settings.keys.select
			local interface_options = {}
			for _, user_interface in ipairs(app:getUserInterfaces()) do
				interface_options[#interface_options + 1] = user_interface.name
			end
			return {
				ControlFactory.choice(settings, Settings.user_interface, {
					name = localization:get("settings.user_interface"),
					keywords = {"user interface", "ui", "theme"},
					options = interface_options,
					format = function(value) return formatUserInterface(value, app) end,
					form = form,
					popup_container = popup_container,
					on_change = function(value)
						app:setUserInterface(value)
						app:requestReload()
					end,
				}),
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
				ControlFactory.boolean(settings, select_keys.random_preview_position, {
					name = localization:get("settings.random_preview_position"),
					keywords = {"song select", "preview", "random", "position", "music"},
					tip = localization:get("settings.random_preview_position_tip"),
				}),
				ControlFactory.boolean(settings, select_keys.blurred_background, {
					name = localization:get("settings.song_select_blurred_background"),
					keywords = {"song select", "background", "blur", "image"},
					tip = localization:get("settings.song_select_blurred_background_tip"),
				}),
				ControlFactory.boolean(settings, select_keys.carousel, {
					name = localization:get("settings.song_select_carousel"),
					keywords = {"song select", "carousel", "list", "sets", "charts"},
					tip = localization:get("settings.song_select_carousel_tip"),
				}),
				ControlFactory.boolean(settings, select_keys.open_on_startup, {
					name = localization:get("settings.open_song_select_on_startup"),
					keywords = {"song select", "main menu", "startup", "launch"},
					tip = localization:get("settings.open_song_select_on_startup_tip"),
				}),
				ControlFactory.choice(settings, select_keys.score_filter, {
					name = localization:get("settings.score_filter"),
					keywords = {"song select", "scores", "mutators", "timings"},
					tip = localization:get("settings.score_filter_tip"),
					format = function(value)
						return localization:get(value == "No filter"
							and "settings.score_filter_all"
							or "settings.score_filter_unmodified")
					end,
					form = form,
					popup_container = popup_container,
				}),
				ControlFactory.boolean(settings, Settings.keys.misc.mute_on_unfocus, {
					name = localization:get("settings.mute_on_unfocus"),
					keywords = {"mute", "focus", "background", "audio", "volume"},
					tip = localization:get("settings.mute_on_unfocus_tip"),
				}),
				ControlFactory.segmentedChoice(settings, select_keys.diff_column, {
					name = localization:get("settings.difficulty_type"),
					keywords = {"difficulty", "rating", "menus"},
					tip = localization:get("settings.difficulty_type_tip"),
					format = formatDifficulty,
					on_change = on_diff_column_change,
				}),
			}
		end,
	})
end

return UserInterface
