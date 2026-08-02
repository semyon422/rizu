local ControlFactory = require("ui.modals.config.ControlFactory")
local Resources = require("ui.Resources")
local Section = require("ui.modals.config.Section")

---@class ui.modals.config.sections.Offset : ui.modals.config.Section
---@operator call: ui.modals.config.sections.Offset
local Offset = Section + {}

---@param settings sphere.SettingsConfig
function Offset:new(settings)
	Section.new(self, {
		name = "Offset",
		icon = Resources.sprites.icon_metronome,
		build = function()
			return {
				ControlFactory.legacyNumber(settings, {"gameplay", "offset_audio_mode", "bass_sample"}, {
					name = "Universal offset",
					keywords = {"audio", "timing", "latency", "sync"},
					tip = "Apply the same audio offset to all playback modes.",
					min = -0.5,
					max = 0.5,
					step = 0.001,
					value_format = function(value)
						return ("%.3f s"):format(value)
					end,
					on_change = function(value)
						settings.gameplay.offset_audio_mode.bass_fx_tempo = value
					end,
				}),
			}
		end,
	})
end

return Offset
