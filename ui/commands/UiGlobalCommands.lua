local AudioFilePicker = require("rizu.mapperatorinator.AudioFilePicker")

local audio_file_picker = AudioFilePicker()

-- Returns commands specific to this user interface.
---@param game sphere.GameController
---@param ui ui.UserInterface
---@return rizu.command.Command[]
return function(game, ui)
	local commands = {
		{
			id = "ui.global.mapperatorinator",
			title = "Mapperatorinator: Generate Chart",
			description = "Selects audio and opens AI beatmap generation settings",
			callback = function()
				audio_file_picker:pick(function(path, err)
					if err then
						ui.mapperatorinator_workflow.status = err
						ui.modal_manager:attachMapperatorinator()
					elseif path then
						ui.modal_manager.mapperatorinator:setAudioPath(path)
						ui.modal_manager:attachMapperatorinator()
					end
				end)
			end,
		},
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
