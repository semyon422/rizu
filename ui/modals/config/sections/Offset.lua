local ControlFactory = require("ui.modals.config.ControlFactory")
local Resources = require("ui.Resources")
local Section = require("ui.modals.config.Section")
local Settings = require("rizu.config.Settings")

---@class ui.modals.config.sections.Offset : ui.modals.config.Section
---@operator call: ui.modals.config.sections.Offset
local Offset = Section + {}

---@param value number
---@return string
local function formatSeconds(value)
	return ("%.3f s"):format(value)
end

---@param settings rizu.config.Config
---@param localization ui.localization.Localization
function Offset:new(settings, localization)
	Section.new(self, {
		name = localization:get("settings.offset"),
		icon = Resources.sprites.icon_metronome,
		build = function()
			local keys = Settings.keys.gameplay
			local mode_keys = keys.offset_audio_mode
			local controls = {
				ControlFactory.number(settings, mode_keys.bass_sample, {
					name = localization:get("settings.universal_offset"),
					keywords = {"audio", "timing", "latency", "sync"},
					tip = localization:get("settings.universal_offset_tip"),
					value_format = formatSeconds,
					on_change = function(value)
						settings:setNumber(mode_keys.bass_fx_tempo, value)
					end,
				}),
			}

			local formats = {
				{name = "osu!", key = "osu"},
				{name = "Quaver", key = "quaver"},
				{name = "StepMania", key = "stepmania"},
				{name = "KSH", key = "ksm"},
			}
			for _, format in ipairs(formats) do
				controls[#controls + 1] = ControlFactory.number(settings, keys.offset_format[format.key], {
					name = localization:get("settings.format_offset", {format = format.name}),
					keywords = {"audio", "timing", "latency", "sync", "format", format.key, format.name},
					tip = localization:get("settings.format_offset_tip", {format = format.name}),
					value_format = formatSeconds,
				})
			end
			return controls
		end,
	})
end

return Offset
