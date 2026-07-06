---@param ui yi.UserInterface
---@return yi.command_palette.Command[]
return function(ui)
	local game = ui.game

	return {
		{
			id = "gameplay.resume",
			title = "Gameplay: Resume",
			description = "Resumes gameplay from pause",
			callback = function()
				game.gameplayInteractor:changePlayState("play")
			end,
		},
		{
			id = "gameplay.pause",
			title = "Gameplay: Pause",
			description = "Pauses gameplay",
			callback = function()
				game.gameplayInteractor:changePlayState("pause")
			end,
		},
		{
			id = "gameplay.retry",
			title = "Gameplay: Retry",
			description = "Restarts the current chart",
			callback = function()
				game.gameplayInteractor:changePlayState("retry")
			end,
		},
		{
			id = "gameplay.quit",
			title = "Gameplay: Quit",
			description = "Leaves gameplay and opens the appropriate screen",
			callback = function()
				if game.gameplayInteractor:hasResult() then
					ui:setScreen("result")
				elseif game.multiplayerModel.client:isInRoom() then
					ui:setScreen("select")
				else
					ui:setScreen("select")
				end
			end,
		},
		{
			id = "gameplay.skip_intro",
			title = "Gameplay: Skip Intro",
			description = "Skips silence before the first note",
			callback = function()
				game.gameplayInteractor:skipIntro()
			end,
		},
		{
			id = "gameplay.offset_decrease",
			title = "Gameplay: Decrease Local Offset",
			description = "Moves the selected chart local offset back by 1 ms",
			callback = function()
				game.offsetController:increaseLocalOffset(-0.001)
			end,
		},
		{
			id = "gameplay.offset_increase",
			title = "Gameplay: Increase Local Offset",
			description = "Moves the selected chart local offset forward by 1 ms",
			callback = function()
				game.offsetController:increaseLocalOffset(0.001)
			end,
		},
		{
			id = "gameplay.offset_reset",
			title = "Gameplay: Reset Local Offset",
			description = "Resets the selected chart local offset",
			callback = function()
				game.offsetController:resetLocalOffset()
			end,
		},
		{
			id = "gameplay.play_speed_decrease",
			title = "Gameplay: Decrease Play Speed",
			description = "Decreases the gameplay play speed",
			callback = function()
				game.gameplayInteractor:increasePlaySpeed(-1)
			end,
		},
		{
			id = "gameplay.play_speed_increase",
			title = "Gameplay: Increase Play Speed",
			description = "Increases the gameplay play speed",
			callback = function()
				game.gameplayInteractor:increasePlaySpeed(1)
			end,
		},
	}
end
