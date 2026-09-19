local ControlFactory = require("ui.modals.config.ControlFactory")
local Resources = require("ui.Resources")
local Section = require("ui.modals.config.Section")
local Settings = require("rizu.config.Settings")

---@class ui.modals.config.sections.Offset : ui.modals.config.Section
---@operator call: ui.modals.config.sections.Offset
local Offset = Section + {}

---@param settings rizu.config.Config
---@param localization ui.localization.Localization
function Offset:new(settings, localization)
	Section.new(self, {
		name = localization:get("settings.offset"),
		icon = Resources.sprites.icon_metronome,
		build = function()
			local gameplay_keys = Settings.keys.gameplay
			local audio_mode_keys = gameplay_keys.offset_audio_mode
			local controls = {
				ControlFactory.number(settings, audio_mode_keys.bass_sample, {
					name = localization:get("settings.universal_offset"),
					keywords = {"audio", "timing", "latency", "sync"},
					tip = localization:get("settings.universal_offset_tip"),
					value_format = function(value)
						return ("%.3f s"):format(value)
					end,
					on_change = function(value)
						settings:setNumber(audio_mode_keys.bass_fx_tempo, value)
					end,
				}),
			}

			local format_names = {
				osu = "osu!",
				qua = "Quaver",
				sm = "StepMania",
				ksh = "KSH",
			}
			for _, format in ipairs({"osu", "qua", "sm", "ksh"}) do
				local name = format_names[format]
				controls[#controls + 1] = ControlFactory.number(settings, gameplay_keys.offset_format[format], {
					name = localization:get("settings.format_offset", {format = name}),
					keywords = {"audio", "timing", "latency", "sync", "format", format, name},
					tip = localization:get("settings.format_offset_tip", {format = name}),
					value_format = function(value)
						return ("%.3f s"):format(value)
					end,
				})
			end
			return controls
		end,
	})
end

return Offset
