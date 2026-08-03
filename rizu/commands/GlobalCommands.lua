-- Returns the list of globally accessible commands.
---@param game sphere.GameController
---@return rizu.command.Command[]
return function(game)
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
			id = "global.exit",
			title = "Quit/Exit Game",
			description = "Exits the game immediately",
			callback = function()
				love.event.quit()
			end,
		},
		{
			id = "global.screenshot",
			title = "Screenshot: Capture",
			description = "Captures a screenshot",
			callback = function()
				game.app.screenshotModel:capture(false)
			end,
		},
		{
			id = "global.screenshot_open",
			title = "Screenshot: Capture and Open",
			description = "Captures a screenshot and opens it in the file manager",
			callback = function()
				game.app.screenshotModel:capture(true)
			end,
		},
	}
end
