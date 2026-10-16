local ControlFactory = require("ui.modals.config.ControlFactory")
local Resources = require("ui.Resources")
local Section = require("ui.modals.config.Section")
local ScrollSpeed = require("rizu.gameplay.ScrollSpeed")
local Settings = require("rizu.config.Settings")

---@class ui.modals.config.sections.Gameplay : ui.modals.config.Section
---@operator call: ui.modals.config.sections.Gameplay
local Gameplay = Section + {}

---@param value string
---@return string formatted
local function formatScrollSpeedType(value)
	return ({
		default = "Rizu",
		osu = "osu!",
	})[value]
end

---@param settings rizu.config.Config
---@param ui_config ui.UiConfig
---@param localization ui.localization.Localization
---@param form ui.views.form.Form
---@param popup_container ui.views.PopupContainer
function Gameplay:new(settings, ui_config, localization, form, popup_container)
		Section.new(self, {
		name = localization:get("settings.gameplay"),
		icon = Resources.sprites.icon_play,
		build = function(section)
			local keys = Settings.keys.gameplay
			local speed_type = settings:getChoice(keys.speed_type)
			local range = assert(ScrollSpeed.ranges[speed_type])
			local format = assert(ScrollSpeed.formats[speed_type])

			local controls = {
				ControlFactory.segmentedChoice(settings, keys.speed_type, {
					name = localization:get("settings.scroll_speed_type"),
					keywords = {"gameplay", "scroll", "speed", "osu"},
					format = formatScrollSpeedType,
					tip = localization:get("settings.scroll_speed_type_tip"),
					on_change = function()
						section:invalidate()
					end,
				}),
				ControlFactory.number(settings, keys.speed, {
					name = localization:get("settings.scroll_speed"),
					keywords = {"gameplay", "scroll", "speed"},
					tip = localization:get("settings.scroll_speed_tip"),
					min = range[1],
					max = range[2],
					step = range[3],
					from_storage = function(value)
						return ScrollSpeed.toDisplay(speed_type, value)
					end,
					to_storage = function(value)
						return ScrollSpeed.toCanonical(speed_type, value)
					end,
					value_format = function(value)
						return format:format(value)
					end,
				}),
				ControlFactory.boolean(settings, keys.auto_key_sound, {
					name = localization:get("settings.auto_keysound"),
					keywords = {"gameplay", "audio", "auto", "keysound"},
					tip = localization:get("settings.auto_keysound_tip"),
				}),
				ControlFactory.boolean(settings, keys.skin_resources_top_priority, {
					name = localization:get("settings.skin_sounds"),
					keywords = {"gameplay", "audio", "skin", "hit", "sound", "hitsound", "keysound"},
					tip = localization:get("settings.skin_sounds_tip"),
				}),
				ControlFactory.boolean(settings, keys.bga_image, {
					name = localization:get("settings.background_images"),
					keywords = {"gameplay", "background", "animation", "bga", "image"},
					tip = localization:get("settings.background_images_tip"),
				}),
				ControlFactory.boolean(settings, keys.bga_video, {
					name = localization:get("settings.background_videos"),
					keywords = {"gameplay", "background", "animation", "bga", "video"},
					tip = localization:get("settings.background_videos_tip"),
				}),
				ControlFactory.number(settings, keys.osu_cursor_scale, {
					name = localization:get("settings.osu_cursor_scale"),
					keywords = {"gameplay", "osu", "cursor", "scale", "size"},
					tip = localization:get("settings.osu_cursor_scale_tip"),
					value_format = function(value)
						return ("%.2fx"):format(value)
					end,
				}),
			}
			for _, name in ipairs({"prepare", "play_pause", "pause_play", "play_retry", "pause_retry"}) do
				controls[#controls + 1] = ControlFactory.number(settings, keys["time_" .. name], {
					name = localization:get("settings.time_" .. name),
					keywords = {"gameplay", "time", "hold", "pause", "resume", "retry", "restart", "prepare"},
					tip = localization:get("settings.time_" .. name .. "_tip"),
					value_format = function(value)
						return localization:get("settings.time_seconds", {value = ("%.1f"):format(value)})
					end,
				})
			end

			if settings:getBoolean(Settings.keys.misc.enable_cheats) then
				local tempo_factor = settings:getChoice(keys.tempo_factor)
				controls[#controls + 1] = ControlFactory.choice(settings, keys.tempo_factor, {
					name = localization:get("settings.tempo_factor"),
					keywords = {"gameplay", "advanced", "tempo", "bpm", "scroll", "average", "minimum", "maximum"},
					tip = localization:get("settings.tempo_factor_tip"),
					form = form,
					popup_container = popup_container,
					format = function(value)
						return localization:get("settings.tempo_factor_" .. value)
					end,
					on_change = function()
						section:invalidate()
					end,
				})
				if tempo_factor == "primary" then
					controls[#controls + 1] = ControlFactory.number(settings, keys.primary_tempo, {
						name = localization:get("settings.primary_tempo"),
						keywords = {"gameplay", "advanced", "tempo", "bpm", "primary"},
						tip = localization:get("settings.primary_tempo_tip"),
						value_format = function(value)
							return ("%d bpm"):format(value)
						end,
					})
				end
				controls[#controls + 1] = ControlFactory.boolean(settings, keys.swap_velocity_type, {
					name = localization:get("settings.swap_velocity_type"),
					keywords = {"gameplay", "advanced", "velocity", "global", "local", "current", "swap"},
					tip = localization:get("settings.swap_velocity_type_tip"),
				})
			end
			return controls
		end,
	})
end

return Gameplay
