local thread = require("thread")
local pprint = require("pprint")
local stbl = require("stbl")

---@param game sphere.GameController
---@return rizu.command.Command[]
return function(game)
	local reload_result = thread.coro(function()
		game.resultController:replayNoteChartAsync("result", game.scoreSelector.chartplay)
	end)

	return {
		{
			id = "result.reload_result",
			title = "Result: Reload",
			description = "Reloads the selected score result",
			callback = reload_result,
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
			id = "result.dump_replay_info",
			title = "Result: Dump Replay Info",
			description = "Prints replay details to the console",
			callback = function()
				local replay = game.resultController.replay
				if not replay then
					print("[ReplayInfo] no replay loaded")
					return
				end

				print("[ReplayInfo]")
				print("hash: " .. tostring(replay.hash))
				print("index: " .. tostring(replay.index))
				print("modifiers: " .. stbl.encode(replay.modifiers))
				print("rate: " .. tostring(replay.rate))
				print("mode: " .. tostring(replay.mode))
				print("version: " .. tostring(replay.version))
				print("#events: " .. #tostring(replay.events))
				print("pause_count: " .. tostring(replay.pause_count))
				print("created_at: " .. tostring(replay.created_at) .. " " .. os.date("%c", replay.created_at))
				print("nearest: " .. tostring(replay.nearest))
				print("tap_only: " .. tostring(replay.tap_only))
				print("timings: " .. tostring(replay.timings))
				print("subtimings: " .. tostring(replay.subtimings))
				print("healths: " .. tostring(replay.healths))
				print("columns_order: " .. stbl.encode(replay.columns_order))
				print("custom: " .. tostring(replay.custom))
				print("const: " .. tostring(replay.const))
				print("rate_type: " .. tostring(replay.rate_type))
				print("timing_values: " .. pprint.dump(replay.timing_values))
			end,
		},
	}
end
