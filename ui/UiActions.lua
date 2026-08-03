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
	return actions
end

return UiActions
