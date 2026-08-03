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
UiActions.gameplay_skip_intro = "gameplay.skip_intro"
UiActions.editor_toggle_playback = "editor.toggle_playback"

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
		[UiActions.gameplay_skip_intro] = keys.gameplay_skip_intro_bindings,
		[UiActions.editor_toggle_playback] = keys.editor_toggle_playback_bindings,
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
	return actions
end

return UiActions
