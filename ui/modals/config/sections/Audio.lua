local decibel = require("decibel")
local ControlFactory = require("ui.modals.config.ControlFactory")
local Resources = require("ui.Resources")
local Section = require("ui.modals.config.Section")
local Settings = require("rizu.config.Settings")

---@class ui.modals.config.sections.Audio : ui.modals.config.Section
---@operator call: ui.modals.config.sections.Audio
local Audio = Section + {}

local MIN_DECIBELS = -60

---@param value string
---@return string formatted
local function formatVolumeScale(value)
	return value:sub(1, 1):upper() .. value:sub(2)
end

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

---@param settings rizu.config.Config
---@param localization ui.localization.Localization
function Audio:new(settings, localization)
		Section.new(self, {
		name = localization:get("settings.audio"),
		icon = Resources.sprites.icon_volume_1,
		build = function(section)
			local keys = Settings.keys.audio
			local logarithmic = settings:getChoice(keys.volume_type) == "logarithmic"
			local controls = {
				ControlFactory.segmentedChoice(settings, keys.volume_type, {
					name = localization:get("settings.volume_scale"),
					tip = localization:get("settings.volume_scale_tip"),
					format = formatVolumeScale,
					on_change = function()
						section:invalidate()
					end,
				}),
			}
			local volumes = {
				{key = keys.volume_master, name = localization:get("settings.master_volume"), keyword = "master"},
				{key = keys.volume_music, name = localization:get("settings.music_volume"), keyword = "music"},
				{key = keys.volume_keysounds, name = localization:get("settings.keysound_volume"), keyword = "keysounds"},
				{key = keys.volume_metronome, name = localization:get("settings.metronome_volume"), keyword = "metronome"},
			}
			for _, volume in ipairs(volumes) do
				controls[#controls + 1] = ControlFactory.number(settings, volume.key, {
					name = volume.name,
					keywords = {"audio", "sound", volume.keyword},
					tip = localization:get("settings.volume_tip", {kind = volume.name:lower()}),
					min = logarithmic and MIN_DECIBELS or nil,
					max = logarithmic and 0 or nil,
					step = logarithmic and 1 or nil,
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
