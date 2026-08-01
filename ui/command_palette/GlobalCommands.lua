local Settings = require("rizu.config.Settings")

local M = {}

-- Returns the list of globally accessible commands.
---@param game sphere.GameController
---@param ui ui.UserInterface?
---@return ui.command_palette.Command[]
function M.get(game, ui)
	return {
		{
			id = "global.needle",
			title = "Needle",
			description = "Turn natural language into a safe game command",
			arguments = {{
				name = "query",
				type = "string",
				prompt = "Needle:",
			}},
			callback = function() end,
		},
		{
			id = "global.ai_chat",
			title = "AI: Open Chat",
			description = "Opens the local AI agent chat",
			callback = function()
				if ui and ui.modal_manager then
					ui.modal_manager:attachChat()
				end
			end,
		},
		{
			id = "global.exit",
			title = "Quit/Exit Game",
			description = "Exits the game immediately",
			callback = function()
				love.event.quit()
			end
		},
		{
			id = "global.rate",
			title = "Gameplay: Set Playback Rate",
			description = "Sets the playback rate of the music",
			arguments = {
				{
					name = "rate",
					type = "number",
					prompt = "Enter Playback Rate:",
					validate = function(val)
						local num = tonumber(val)
						if not num then
							return false, "Must be a valid number"
						end

						local timeRateModel = game.timeRateModel
						local replayBase = game.replayBase
						if not timeRateModel or not replayBase then
							return true
						end

						local range = timeRateModel.range[replayBase.rate_type]
						if range and (num < range[1] or num > range[2]) then
							return false, ("Rate must be between %s and %s"):format(range[1], range[2])
						end
						return true
					end
				}
			},
			callback = function(args)
				if game.timeRateModel then
					game.timeRateModel:set(args.rate)
					game.modifierSelectModel:change()
				end
			end
		},
		{
			id = "global.screenshot",
			title = "Screenshot: Capture",
			description = "Captures a screenshot",
			callback = function()
				game.app.screenshotModel:capture(false)
			end
		},
		{
			id = "global.screenshot_open",
			title = "Screenshot: Capture and Open",
			description = "Captures a screenshot and opens it in the file manager",
			callback = function()
				game.app.screenshotModel:capture(true)
			end
		},
		{
			id = "global.toggle_fps",
			title = "FPS: Toggle",
			description = "Toggles the FPS overlay",
			callback = function()
				local show_fps = game.settings:getBoolean(Settings.show_fps)
				game.settings:setBoolean(Settings.show_fps, not show_fps)
			end
		},
		{
			id = "global.open_editor",
			title = "Editor: Open",
			description = "Opens the editor screen",
			callback = function()
				if ui and ui.editor and game.chartSelector:chartExists() then
					ui:setScreen(ui.editor)
				end
			end
		}
	}
end


return M
