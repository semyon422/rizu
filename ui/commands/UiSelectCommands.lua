local thread = require("thread")

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
				if game.chartSelector:chartExists() then
					ui:loadSelectedChart(false, false, true)
				end
			end,
		},
		{
			id = "ui.select.autoplay",
			title = "Select: Autoplay",
			description = "Starts the selected chart with autoplay enabled",
			callback = function()
				if game.chartSelector:chartExists() then
					ui:loadSelectedChart(true, false, true)
				end
			end,
		},
		{
			id = "ui.select.local_replay",
			title = "Select: Watch Local Replay",
			description = "Plays the latest local attempt of the selected chart, for gamemodes that do not save scores",
			callback = function()
				local view = game.chartSelector.chartview
				if not view or not game.gameplayInteractor.replay_stores[view.chartmeta_mode] then return end
				local ok, err = game.gameplayInteractor:loadLocalReplay(view.hash, view.index, view.chartmeta_mode)
				if not ok then ui.chart_loading:showError(err) end
				ui:setScreen(ui.chart_loading, true)
			end,
		},
		{
			id = "ui.select.open_result",
			title = "Select: Open Result",
			description = "Opens the selected score result",
			callback = function()
				if game.chartSelector:chartExists() and game.scoreSelector.chartplay then
					local chartplay = game.scoreSelector.chartplay
					thread.coro(function()
						local ok, err = pcall(function()
							game.resultController:replayNoteChartAsync("result", chartplay)
						end)
						if ok then
							ui:setScreen(ui.result)
						else
							print("failed to load score:", err)
							ui:setScreen(ui.song_select)
						end
					end)()
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
