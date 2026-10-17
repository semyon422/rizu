---@param game sphere.GameController
---@param ui ui.UserInterface
---@return rizu.command.Command[]
return function(game, ui)
	return {
		{
			id = "ui.select.play",
			title = "Select: Play",
			description = "Starts the selected chart",
			callback = function()
				if ui.api.charts:canPlaySelectedChart() then
					ui:loadSelectedChart(false, false, true)
				end
			end,
		},
		{
			id = "ui.select.autoplay",
			title = "Select: Autoplay",
			description = "Starts the selected chart with autoplay enabled",
			callback = function()
				if ui.api.charts:canPlaySelectedChart() then
					ui:loadSelectedChart(true, false, true)
				end
			end,
		},
		{
			id = "ui.select.local_replay",
			title = "Select: Watch Local Replay",
			description = "Plays the latest local attempt of the selected chart, for gamemodes that do not save scores",
			callback = function()
				if ui.api.play:hasLocalReplays() then
					ui:loadSelectedChart(false, false, true, true)
				end
			end,
		},
		{
			id = "ui.select.open_result",
			title = "Select: Open Result",
			description = "Opens the selected score result",
			callback = function()
				if ui.api.charts:canPlaySelectedChart() and ui.api.scores:getSelected() then
					ui.api.scores:loadSelectedResult(function(ok)
						ui:setScreen(ok and ui.result or ui.song_select)
					end)
				end
			end,
		},
		{
			id = "ui.select.open_input",
			title = "Modal: Open Input",
			description = "Opens input bindings",
			callback = function()
				ui.modal_manager:attachInput()
			end,
		},
		--[[{
			id = "ui.select.open_modifiers",
			title = "Modal: Open Modifiers",
			description = "Opens gameplay modifiers",
			callback = function() ui.modals:open("modifiers") end,
		},
		{
			id = "ui.select.open_filters",
			title = "Modal: Open Filters",
			description = "Opens select filters",
			callback = function() ui.modals:open("filters") end,
		},
		{
			id = "ui.select.open_input",
			title = "Modal: Open Input",
			description = "Opens input bindings",
			callback = function() ui.modals:open("input") end,
		},
		{
			id = "ui.select.open_noteskins",
			title = "Modal: Open Note Skins",
			description = "Opens note skin selection",
			callback = function() ui.modals:open("noteskins") end,
		},]]
	}
end
