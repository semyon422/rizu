local ControlFactory = require("ui.modals.config.ControlFactory")
local Resources = require("ui.Resources")
local Section = require("ui.modals.config.Section")
local Settings = require("rizu.config.Settings")

---@class ui.modals.config.sections.Offset : ui.modals.config.Section
---@operator call: ui.modals.config.sections.Offset
local Offset = Section + {}

---@param settings rizu.config.Config
function Offset:new(settings)
	Section.new(self, {
		name = "Offset",
		icon = Resources.sprites.icon_metronome,
		build = function()
			local keys = Settings.keys.gameplay.offset_audio_mode
			return {
				ControlFactory.number(settings, keys.bass_sample, {
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
						settings:setNumber(keys.bass_fx_tempo, value)
					end,
				}),
			}
		end,
	})
end

return Offset
