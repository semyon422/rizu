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
					game.gameplayInteractor.replaying = false
					game.gameplayInteractor.aim_replay = nil
					game.gameplayInteractor.autoplay = false
					ui:setScreen(ui.chart_loading)
				end
			end,
		},
		{
			id = "ui.select.autoplay",
			title = "Select: Autoplay",
			description = "Starts the selected chart with autoplay enabled",
			callback = function()
				if game.chartSelector:chartExists() then
					game.gameplayInteractor.replaying = false
					game.gameplayInteractor.aim_replay = nil
					game.gameplayInteractor.autoplay = true
					ui:setScreen(ui.chart_loading)
				end
			end,
		},
		{
			id = "ui.select.aim_replay",
			title = "Select: Watch Local Aim Replay",
			description = "Plays the latest diagnostic circle-only Aim replay for the selected chart",
			callback = function()
				local view = game.chartSelector.chartview
				if view and view.inputmode == "1osu" then
					local ok, err = game.gameplayInteractor:loadAimReplay(view.hash, view.index)
					if ok then
						ui:setScreen(ui.chart_loading)
					else
						ui.chart_loading:showError(err)
						ui:setScreen(ui.chart_loading)
					end
				end
			end,
		},
		{
			id = "ui.select.catch_replay",
			title = "Select: Watch Local Catch Replay",
			description = "Plays the latest local Catch attempt",
			callback = function()
				local view = game.chartSelector.chartview
				if view and view.inputmode == "1fruits" then
					local ok, err = game.gameplayInteractor:loadAimReplay(view.hash, view.index, true)
					if not ok then ui.chart_loading:showError(err) end
					ui:setScreen(ui.chart_loading)
				end
			end,
		},
		{
			id = "ui.select.taiko_replay",
			title = "Select: Watch Local Taiko Replay",
			description = "Plays the latest local native Taiko attempt",
			callback = function()
				local view = game.chartSelector.chartview
				if view and (view.inputmode == "1taiko" or view.inputmode == "2key" and view.format == "osu") then
					local ok, err = game.gameplayInteractor:loadAimReplay(view.hash, view.index, "taiko")
					if not ok then ui.chart_loading:showError(err) end
					ui:setScreen(ui.chart_loading)
				end
			end,
		},
		{
			id = "ui.select.sdvx_replay",
			title = "Select: Watch Local SDVX Replay",
			description = "Plays the latest native KSH attempt",
			callback = function()
				local view = game.chartSelector.chartview
				if view and view.format == "ksm" then
					local ok, err = game.gameplayInteractor:loadAimReplay(view.hash, view.index, "sdvx")
					if not ok then ui.chart_loading:showError(err) end
					ui:setScreen(ui.chart_loading)
				end
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
