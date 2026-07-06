local thread = require("thread")

---@param ui yi.UserInterface
---@return yi.command_palette.Command[]
return function(ui)
	local game = ui.game

	---@param mode "retry"|"replay"|"result"
	local play = thread.coro(function(mode)
		game.resultController:replayNoteChartAsync(mode, game.scoreSelector.chartplay)
		if mode == "result" then
			return
		end
		ui:setScreen("gameplay")
	end)

	return {
		{
			id = "result.retry",
			title = "Result: Retry",
			description = "Retries the result chart",
			callback = function()
				play("retry")
			end,
		},
		{
			id = "result.watch_replay",
			title = "Result: Watch Replay",
			description = "Watches the selected score replay",
			callback = function()
				play("replay")
			end,
		},
		{
			id = "result.reload_result",
			title = "Result: Reload",
			description = "Reloads the selected score result",
			callback = function()
				play("result")
			end,
		},
		{
			id = "result.load_score",
			title = "Result: Load Score",
			description = "Loads a score by list index",
			arguments = {
				{
					name = "index",
					type = "number",
					prompt = "Enter score index:",
				},
			},
			callback = thread.coro(function(args)
				game.gameInteractor:loadScoreAsync(args.index)
			end),
		},
		{
			id = "result.submit",
			title = "Result: Resubmit Score",
			description = "Submits the selected local score",
			callback = function()
				local chartplay = game.scoreSelector.chartplay
				if chartplay and chartplay.replay_hash then
					game.onlineModel.onlineScoreManager:submit(game.chartSelector.chartview, chartplay.replay_hash)
				end
			end,
		},
		{
			id = "result.back",
			title = "Result: Back to Select",
			description = "Returns to chart selection",
			callback = function()
				game.resultController:unload()
				ui:setScreen("select")
			end,
		},
	}
end
