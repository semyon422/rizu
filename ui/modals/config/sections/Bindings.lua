local ControlFactory = require("ui.modals.config.ControlFactory")
local Resources = require("ui.Resources")
local Section = require("ui.modals.config.Section")

---@class ui.modals.config.sections.Bindings : ui.modals.config.Section
---@operator call: ui.modals.config.sections.Bindings
local Bindings = Section + {}

---@class ui.modals.config.sections.BindingDefinition
---@field key string
---@field name string
---@field keywords string[]
---@field tip string

---@param ui_config ui.UiConfig
---@param localization ui.localization.Localization
function Bindings:new(ui_config, localization)
	local keys = ui_config.keys
		local function binding(id, key, keywords)
		return {
			key = key,
			name = localization:get("settings.binding_" .. id),
			keywords = keywords,
			tip = localization:get("settings.binding_" .. id .. "_tip"),
		}
	end
	local definitions = {
		binding("command_palette", keys.command_palette_bindings, {"global", "command", "palette"}),
		binding("open_settings", keys.open_config_bindings, {"global", "config", "settings"}),
		binding("accept", keys.accept_bindings, {"ui", "confirm", "enter"}),
		binding("cancel", keys.cancel_bindings, {"ui", "escape", "back"}),
		binding("left", keys.left_bindings, {"ui", "navigation", "left"}),
		binding("right", keys.right_bindings, {"ui", "navigation", "right"}),
		binding("up", keys.up_bindings, {"ui", "navigation", "up"}),
		binding("down", keys.down_bindings, {"ui", "navigation", "down"}),
		binding("random_chart", keys.select_random_bindings, {"song select", "random", "f2"}),
		binding("audio_preview", keys.toggle_audio_preview_bindings, {"song select", "audio", "preview"}),
		binding("rate_decrease", keys.select_time_rate_decrease_bindings, {"song select", "rate", "f5"}),
		binding("rate_increase", keys.select_time_rate_increase_bindings, {"song select", "rate", "f6"}),
		binding("pause", keys.gameplay_pause_bindings, {"gameplay", "pause", "escape"}),
		binding("quit", keys.gameplay_quit_bindings, {"gameplay", "quit", "shift", "escape"}),
		binding("retry", keys.gameplay_retry_bindings, {"gameplay", "restart", "retry"}),
		binding("skip_intro", keys.gameplay_skip_intro_bindings, {"gameplay", "intro", "space"}),
		binding("offset_decrease", keys.gameplay_offset_decrease_bindings, {"gameplay", "offset", "timing"}),
		binding("offset_increase", keys.gameplay_offset_increase_bindings, {"gameplay", "offset", "timing"}),
		binding("offset_reset", keys.gameplay_offset_reset_bindings, {"gameplay", "offset", "timing"}),
		binding("speed_decrease", keys.gameplay_play_speed_decrease_bindings, {"gameplay", "scroll", "speed", "f3"}),
		binding("speed_increase", keys.gameplay_play_speed_increase_bindings, {"gameplay", "scroll", "speed", "f4"}),
		binding("editor_playback", keys.editor_toggle_playback_bindings, {"editor", "play", "pause"}),
		binding("screenshot", keys.global_screenshot_bindings, {"global", "screenshot", "f12"}),
		binding("screenshot_open", keys.global_screenshot_open_bindings, {"global", "screenshot", "open"}),
		binding("volume_increase", keys.master_volume_increase_bindings, {"global", "audio", "volume", "master"}),
		binding("volume_decrease", keys.master_volume_decrease_bindings, {"global", "audio", "volume", "master"}),
	} ---@type ui.modals.config.sections.BindingDefinition[]

	Section.new(self, {
		name = localization:get("settings.bindings"),
		icon = Resources.sprites.icon_keyboard,
		build = function()
			local controls = {} ---@type ui.views.form.FormControl[]
			for _, definition in ipairs(definitions) do
				controls[#controls + 1] = ControlFactory.keyBindings(ui_config, definition.key, definition)
			end
			return controls
		end,
	})
end

return Bindings
