local decibel = require("decibel")
local ControlFactory = require("ui.modals.config.ControlFactory")
local Label = require("ui.views.Label")
local Resources = require("ui.Resources")
local Section = require("ui.modals.config.Section")
local Settings = require("rizu.config.Settings")

---@class ui.modals.config.sections.Audio : ui.modals.config.Section
---@operator call: ui.modals.config.sections.Audio
local Audio = Section + {}

local MIN_DECIBELS = -60

---@param preset rizu.AudioDevicePreset
---@param localization ui.localization.Localization
---@return string formatted
local function formatLatencyPreset(preset, localization)
	return localization:get("settings.audio_latency_" .. preset)
end

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

---@param value number
---@param localization ui.localization.Localization
---@return string formatted
local function formatMilliseconds(value, localization)
	if value == 0 then
		return localization:get("settings.audio_latency_system_value")
	end
	return localization:get("settings.audio_latency_milliseconds", {value = value})
end

---@param settings rizu.config.Config
---@param localization ui.localization.Localization
---@param audio_model rizu.AudioModel?
---@param form ui.views.form.Form?
---@param popup_container ui.views.PopupContainer?
function Audio:new(settings, localization, audio_model, form, popup_container)
	Section.new(self, {
		name = localization:get("settings.audio"),
		icon = Resources.sprites.icon_volume_1,
		build = function(section)
			local keys = Settings.keys.audio
			local logarithmic = settings:getChoice(keys.volume_type) == "logarithmic"
			---@type gui.View[]
			local controls = {}
			if jit.os == "Linux" and audio_model then
				controls[#controls + 1] = ControlFactory.segmentedChoice(settings, keys.backend, {
					name = localization:get("settings.audio_backend"),
					keywords = {"audio", "backend", "pipewire", "device"},
					tip = localization:get("settings.audio_backend_tip"),
					options = {"bass_default", "pipewire_low_latency"},
					format = function(backend)
						return localization:get("settings.audio_backend_" .. backend)
					end,
				})
			end
			controls[#controls + 1] = ControlFactory.choice(settings, keys.device_preset, {
				form = form,
				popup_container = popup_container,
				name = localization:get("settings.audio_latency"),
				keywords = {"audio", "latency", "buffer", "period"},
				tip = localization:get("settings.audio_latency_tip"),
				format = function(preset)
					return formatLatencyPreset(preset, localization)
				end,
				on_change = function()
					section:invalidate()
				end,
			})
			controls[#controls + 1] = ControlFactory.segmentedChoice(settings, keys.volume_type, {
				name = localization:get("settings.volume_scale"),
				tip = localization:get("settings.volume_scale_tip"),
				format = formatVolumeScale,
				on_change = function()
					section:invalidate()
				end,
			})
			if audio_model then
				local status = audio_model:getStatus()
				controls[#controls + 1] = Label({
					font_name = "medium",
					font_size = 16,
					text = localization:get("settings.audio_device_status", {
						name = status.device_name,
						driver = status.device_driver ~= "" and status.device_driver or "—",
					}),
				})
				controls[#controls + 1] = Label({
					font_name = "medium",
					font_size = 16,
					text = localization:get("settings.audio_latency_status", {
						latency = status.latency,
						minimum = status.min_buffer,
						period = status.period,
						buffer = status.buffer,
					}),
				})
				if status.warning then
					controls[#controls + 1] = Label({
						font_name = "medium",
						font_size = 16,
						text = localization:get("settings.audio_startup_warning", {warning = status.warning}),
					})
				end
			end
			if settings:getChoice(keys.device_preset) == "custom" then
				controls[#controls + 1] = ControlFactory.number(settings, keys.device_period, {
					name = localization:get("settings.audio_period"),
					keywords = {"audio", "latency", "period", "custom"},
					tip = localization:get("settings.audio_period_tip"),
					value_format = function(value)
						return formatMilliseconds(value, localization)
					end,
				})
				controls[#controls + 1] = ControlFactory.number(settings, keys.device_buffer, {
					name = localization:get("settings.audio_buffer"),
					keywords = {"audio", "latency", "buffer", "custom"},
					tip = localization:get("settings.audio_buffer_tip"),
					value_format = function(value)
						return formatMilliseconds(value, localization)
					end,
				})
			end
			local volumes = {
				{key = keys.volume_master, name = localization:get("settings.master_volume"), keyword = "master"},
				{key = keys.volume_music, name = localization:get("settings.music_volume"), keyword = "music"},
				{key = keys.volume_keysounds, name = localization:get("settings.keysound_volume"), keyword = "keysounds"},
				{key = keys.volume_metronome, name = localization:get("settings.metronome_volume"), keyword = "metronome"},
			}
			local function addVolume(key, name, keywords, tip)
				controls[#controls + 1] = ControlFactory.number(settings, key, {
					name = name,
					keywords = keywords,
					tip = tip,
					min = logarithmic and MIN_DECIBELS or nil,
					max = logarithmic and 0 or nil,
					step = logarithmic and 1 or nil,
					from_storage = logarithmic and toDecibels or nil,
					to_storage = logarithmic and toLinear or nil,
					value_format = logarithmic and formatDecibels or formatLinear,
				})
			end
			for _, volume in ipairs(volumes) do
				addVolume(
					volume.key,
					volume.name,
					{"audio", "sound", volume.keyword},
					localization:get("settings.volume_tip", {kind = volume.name:lower()})
				)
			end

			local format_names = {
				sphere = "Sphere",
				osu = "osu!",
				o2jam = "O2Jam",
				stepmania = "StepMania",
				quaver = "Quaver",
				ksm = "KSH",
			}
			for _, format in ipairs({"sphere", "osu", "o2jam", "stepmania", "quaver", "ksm"}) do
				local name = format_names[format]
				addVolume(
					keys.volume_keysounds_format[format],
					localization:get("settings.format_keysound_volume", {format = name}),
					{"audio", "sound", "keysound", "format", format, name},
					localization:get("settings.format_keysound_volume_tip", {format = name})
				)
			end
			return controls
		end,
	})
end

return Audio
