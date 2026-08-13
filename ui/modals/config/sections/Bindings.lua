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
function Bindings:new(ui_config)
	local keys = ui_config.keys
	local definitions = {
		{key = keys.command_palette_bindings, name = "Command palette", keywords = {"global", "command", "palette"}, tip = "Open the command palette."},
		{key = keys.open_config_bindings, name = "Open settings", keywords = {"global", "config", "settings"}, tip = "Open this settings window."},
		{key = keys.accept_bindings, name = "Accept", keywords = {"ui", "confirm", "enter"}, tip = "Confirm the selected UI item."},
		{key = keys.cancel_bindings, name = "Cancel / Back", keywords = {"ui", "escape", "back"}, tip = "Close a modal or return to the previous screen."},
		{key = keys.left_bindings, name = "Navigate left", keywords = {"ui", "navigation", "left"}, tip = "Move left in UI controls."},
		{key = keys.right_bindings, name = "Navigate right", keywords = {"ui", "navigation", "right"}, tip = "Move right in UI controls."},
		{key = keys.up_bindings, name = "Navigate up", keywords = {"ui", "navigation", "up"}, tip = "Move up in UI controls."},
		{key = keys.down_bindings, name = "Navigate down", keywords = {"ui", "navigation", "down"}, tip = "Move down in UI controls."},
		{key = keys.select_random_bindings, name = "Select random chart", keywords = {"song select", "random", "f2"}, tip = "Move to a random chart on Song Select."},
		{key = keys.toggle_audio_preview_bindings, name = "Pause / resume preview", keywords = {"song select", "audio", "preview"}, tip = "Pause or resume Song Select preview audio."},
		{key = keys.select_time_rate_decrease_bindings, name = "Decrease time rate", keywords = {"song select", "rate", "f5"}, tip = "Decrease the selected playback rate."},
		{key = keys.select_time_rate_increase_bindings, name = "Increase time rate", keywords = {"song select", "rate", "f6"}, tip = "Increase the selected playback rate."},
		{key = keys.gameplay_pause_bindings, name = "Pause gameplay", keywords = {"gameplay", "pause", "escape"}, tip = "Pause or resume gameplay."},
		{key = keys.gameplay_quit_bindings, name = "Quit gameplay", keywords = {"gameplay", "quit", "shift", "escape"}, tip = "Return to Song Select during gameplay."},
		{key = keys.gameplay_retry_bindings, name = "Retry gameplay", keywords = {"gameplay", "restart", "retry"}, tip = "Restart the current chart."},
		{key = keys.gameplay_skip_intro_bindings, name = "Skip intro", keywords = {"gameplay", "intro", "space"}, tip = "Skip silence before the first note."},
		{key = keys.gameplay_offset_decrease_bindings, name = "Decrease local offset", keywords = {"gameplay", "offset", "timing"}, tip = "Decrease the current chart's local offset by 1 ms."},
		{key = keys.gameplay_offset_increase_bindings, name = "Increase local offset", keywords = {"gameplay", "offset", "timing"}, tip = "Increase the current chart's local offset by 1 ms."},
		{key = keys.gameplay_offset_reset_bindings, name = "Reset local offset", keywords = {"gameplay", "offset", "timing"}, tip = "Reset the current chart's local offset."},
		{key = keys.gameplay_play_speed_decrease_bindings, name = "Decrease play speed", keywords = {"gameplay", "scroll", "speed", "f3"}, tip = "Decrease gameplay scroll speed."},
		{key = keys.gameplay_play_speed_increase_bindings, name = "Increase play speed", keywords = {"gameplay", "scroll", "speed", "f4"}, tip = "Increase gameplay scroll speed."},
		{key = keys.editor_toggle_playback_bindings, name = "Editor playback", keywords = {"editor", "play", "pause"}, tip = "Toggle editor playback."},
		{key = keys.global_screenshot_bindings, name = "Capture screenshot", keywords = {"global", "screenshot", "f12"}, tip = "Save a screenshot."},
		{key = keys.global_screenshot_open_bindings, name = "Capture and open screenshot", keywords = {"global", "screenshot", "open"}, tip = "Save a screenshot and open it in the file manager."},
	} ---@type ui.modals.config.sections.BindingDefinition[]

	Section.new(self, {
		name = "Bindings",
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
