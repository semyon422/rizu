local decibel = require("decibel")
local ControlFactory = require("ui.modals.config.ControlFactory")
local Resources = require("ui.Resources")
local Section = require("ui.modals.config.Section")

---@class ui.modals.config.sections.Audio : ui.modals.config.Section
---@operator call: ui.modals.config.sections.Audio
local Audio = Section + {}

local MIN_DECIBELS = -60

---@param value number
---@return number decibels
local function toDecibels(value)
	return math.max(MIN_DECIBELS, decibel.f_to_lf(math.max(0, math.min(1, value))))
end

---@param value number
---@return number linear
local function toLinear(value)
	return decibel.lf_to_f(value)
end

---@param value number
---@return string formatted
local function formatLinear(value)
	return ("%d%%"):format(math.floor(value * 100 + 0.5))
end

---@param value number
---@return string formatted
local function formatDecibels(value)
	return ("%d dB"):format(value)
end

---@param settings sphere.SettingsConfig
function Audio:new(settings)
	Section.new(self, {
		name = "Audio Volume",
		icon = Resources.sprites.icon_volume_1,
		build = function(section)
			local audio = settings.audio
			local logarithmic = audio.volumeType == "logarithmic"
			local controls = {
				ControlFactory.legacyChoice(settings, {"audio", "volumeType"}, {
					name = "Volume scale",
					options = {"linear", "logarithmic"},
					tip = "Choose whether volume sliders use percentages or decibels.",
					on_change = function()
						section:invalidate()
					end,
				}),
			}
			local names = {
				master = "Master volume",
				music = "Music volume",
				keysounds = "Keysound volume",
				metronome = "Metronome volume",
			}
			for _, key in ipairs({"master", "music", "keysounds", "metronome"}) do
				controls[#controls + 1] = ControlFactory.legacyNumber(settings, {"audio", "volume", key}, {
					name = names[key],
					keywords = {"audio", "sound", key},
					tip = "Adjust the " .. key .. " output level.",
					min = logarithmic and MIN_DECIBELS or 0,
					max = logarithmic and 0 or 1,
					step = logarithmic and 1 or 0.01,
					width = 780,
					from_storage = logarithmic and toDecibels or nil,
					to_storage = logarithmic and toLinear or nil,
					value_format = logarithmic and formatDecibels or formatLinear,
				})
			end
			return controls
		end,
	})
end

return Audio
