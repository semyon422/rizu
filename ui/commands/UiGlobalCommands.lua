-- Returns commands specific to this user interface.
---@param game sphere.GameController
---@param ui ui.UserInterface
---@return rizu.command.Command[]
return function(game, ui)
	local commands = {
		{
			id = "ui.global.toggle_fps",
			title = "FPS: Toggle",
			description = "Toggles the FPS overlay",
			callback = function()
				local show_fps = ui.config:getBoolean("show_fps")
				ui.config:setBoolean("show_fps", not show_fps)
			end,
		},
		{
			id = "ui.global.open_editor",
			title = "Editor: Open",
			description = "Opens the editor screen",
			callback = function()
				if game.chartSelector:chartExists() then
					ui:setScreen(ui.editor)
				end
			end,
		},
	}
	if game.aiChatModel then
		table.insert(commands, 1, {
			id = "ui.global.ai_chat",
			title = "AI: Open Chat",
			description = "Opens the local AI agent chat",
			callback = function()
				ui.modal_manager:attachChat()
			end,
		})
	end
	return commands
end
