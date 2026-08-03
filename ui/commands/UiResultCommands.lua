local thread = require("thread")

---@param ui ui.UserInterface
---@return rizu.command.Command[]
return function(ui)
	local game = ui.game

	---@param mode "retry"|"replay"
	local play = thread.coro(function(mode)
		game.resultController:replayNoteChartAsync(mode, game.scoreSelector.chartplay)
		ui:setScreen(ui.gameplay)
	end)

	return {
		{
			id = "ui.result.retry",
			title = "Result: Retry",
			description = "Retries the result chart",
			callback = function() play("retry") end,
		},
		{
			id = "ui.result.watch_replay",
			title = "Result: Watch Replay",
			description = "Watches the selected score replay",
			callback = function() play("replay") end,
		},
		{
			id = "ui.result.back",
			title = "Result: Back to Select",
			description = "Returns to chart selection",
			callback = function()
				game.resultController:unload()
				ui:setScreen(ui.song_select, true)
			end,
		},
	}
end
