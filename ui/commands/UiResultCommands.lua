---@param ui ui.UserInterface
---@return rizu.command.Command[]
return function(ui)
	local result = ui.api.result

	---@param ok boolean
	local function play(ok)
		if ok then
			ui:setScreen(ui.gameplay)
		end
	end

	return {
		{
			id = "ui.result.retry",
			title = "Result: Retry",
			description = "Retries the result chart",
			callback = function() result:retry(play) end,
		},
		{
			id = "ui.result.watch_replay",
			title = "Result: Watch Replay",
			description = "Watches the selected score replay",
			callback = function() result:watch(play) end,
		},
		{
			id = "ui.result.open_rescore",
			title = "Result: Recalculate Score",
			description = "Counts this play again with another scoring system, hit windows stay as played",
			callback = function()
				if result:hasScore() then
					ui.modal_manager:attachRescore()
				end
			end,
		},
		{
			id = "ui.result.back",
			title = "Result: Back to Select",
			description = "Returns to chart selection",
			callback = function()
				result:close()
				ui:setScreen(ui.song_select, true)
			end,
		},
	}
end
