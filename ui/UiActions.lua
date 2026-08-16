local ActionMap = require("gui.input.ActionMap")

---@class ui.UiActions
local UiActions = {}

UiActions.command_palette = "ui.command_palette"
UiActions.open_config = "ui.open_config"
UiActions.accept = "ui.accept"
UiActions.cancel = "ui.cancel"
UiActions.left = "ui.left"
UiActions.right = "ui.right"
UiActions.up = "ui.up"
UiActions.down = "ui.down"
UiActions.delete_backward = "ui.delete_backward"
UiActions.delete_forward = "ui.delete_forward"
UiActions.move_to_start = "ui.move_to_start"
UiActions.move_to_end = "ui.move_to_end"
UiActions.clear_field = "ui.clear_field"
UiActions.gameplay_pause = "gameplay.pause"
UiActions.gameplay_quit = "gameplay.quit"
UiActions.gameplay_retry = "gameplay.retry"
UiActions.gameplay_skip_intro = "gameplay.skip_intro"
UiActions.gameplay_offset_decrease = "gameplay.offset_decrease"
UiActions.gameplay_offset_increase = "gameplay.offset_increase"
UiActions.gameplay_offset_reset = "gameplay.offset_reset"
UiActions.gameplay_play_speed_decrease = "gameplay.play_speed_decrease"
UiActions.gameplay_play_speed_increase = "gameplay.play_speed_increase"
UiActions.select_random = "select.random"
UiActions.select_time_rate_decrease = "select.time_rate_decrease"
UiActions.select_time_rate_increase = "select.time_rate_increase"
UiActions.global_screenshot = "global.screenshot"
UiActions.global_screenshot_open = "global.screenshot_open"
UiActions.master_volume_increase = "global.master_volume_increase"
UiActions.master_volume_decrease = "global.master_volume_decrease"
UiActions.editor_toggle_playback = "editor.toggle_playback"
UiActions.toggle_audio_preview = "toggle_audio_preview"
UiActions.refresh_song_select = "ui.refresh_song_select"

---@param config ui.UiConfig
---@return gui.input.ActionMap
function UiActions.createMap(config)
	local keys = config.keys
	local actions = ActionMap()
	local definitions = {
		[UiActions.command_palette] = keys.command_palette_bindings,
		[UiActions.open_config] = keys.open_config_bindings,
		[UiActions.accept] = keys.accept_bindings,
		[UiActions.cancel] = keys.cancel_bindings,
		[UiActions.left] = keys.left_bindings,
		[UiActions.right] = keys.right_bindings,
		[UiActions.up] = keys.up_bindings,
		[UiActions.down] = keys.down_bindings,
		[UiActions.gameplay_pause] = keys.gameplay_pause_bindings,
		[UiActions.gameplay_quit] = keys.gameplay_quit_bindings,
		[UiActions.gameplay_retry] = keys.gameplay_retry_bindings,
		[UiActions.gameplay_skip_intro] = keys.gameplay_skip_intro_bindings,
		[UiActions.gameplay_offset_decrease] = keys.gameplay_offset_decrease_bindings,
		[UiActions.gameplay_offset_increase] = keys.gameplay_offset_increase_bindings,
		[UiActions.gameplay_offset_reset] = keys.gameplay_offset_reset_bindings,
		[UiActions.gameplay_play_speed_decrease] = keys.gameplay_play_speed_decrease_bindings,
		[UiActions.gameplay_play_speed_increase] = keys.gameplay_play_speed_increase_bindings,
		[UiActions.select_random] = keys.select_random_bindings,
		[UiActions.select_time_rate_decrease] = keys.select_time_rate_decrease_bindings,
		[UiActions.select_time_rate_increase] = keys.select_time_rate_increase_bindings,
		[UiActions.global_screenshot] = keys.global_screenshot_bindings,
		[UiActions.global_screenshot_open] = keys.global_screenshot_open_bindings,
		[UiActions.master_volume_increase] = keys.master_volume_increase_bindings,
		[UiActions.master_volume_decrease] = keys.master_volume_decrease_bindings,
		[UiActions.editor_toggle_playback] = keys.editor_toggle_playback_bindings,
		[UiActions.toggle_audio_preview] = keys.toggle_audio_preview_bindings,
	}
	for action, key in pairs(definitions) do
		actions:defineAction(action, config:getKeyBindings(key))
		config:subscribeKeyBindings(key, function(bindings)
			actions:defineAction(action, bindings)
		end)
	end

	actions:defineAction(UiActions.delete_backward, {{key = "backspace", allow_repeat = true}})
	actions:defineAction(UiActions.delete_forward, {{key = "delete", allow_repeat = true}})
	actions:defineAction(UiActions.move_to_start, {{key = "home", allow_repeat = true}})
	actions:defineAction(UiActions.move_to_end, {{key = "end", allow_repeat = true}})
	actions:defineAction(UiActions.clear_field, {{control = true, key = "backspace"}})
	actions:defineAction(UiActions.refresh_song_select, {{key = "f5"}})
	return actions
end

return UiActions
