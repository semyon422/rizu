---@param game sphere.GameController
return function(game)
	return {
		{
			id = "select.export_osu",
			title = "Export chart: To .osu",
			description = "Exports the selected chart into userdata/export",
			callback = function()
				game.chartExporter:exportToOsu(game.chartSelector, game.replayBase)
			end
		},
		{
			id = "select.open_chart_folder",
			title = "File: Open chart folder",
			description = "Opens the folder of the selected chart in the file manager",
			callback = function()
				game.selectionActions:openDirectory()
			end
		},
		{
			id = "select.open_location_folder",
			title = "File: Open location folder",
			description = "Opens the folder of the selected location in the file manager",
			callback = function()
				error("TODO")
			end
		},
	}
end
