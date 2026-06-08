local M = {}

-- Returns the list of globally accessible commands.
---@param game sphere.GameController
---@return yi.command_palette.Command[]
function M.get(game)
	return {
		{
			id = "global.exit",
			title = "Quit/Exit Game",
			description = "Exits the game immediately",
			callback = function()
				love.event.quit()
			end
		},
		{
			id = "global.rate",
			title = "Gameplay: Set Playback Rate",
			description = "Sets the playback rate of the music",
			arguments = {
				{
					name = "rate",
					type = "number",
					prompt = "Enter Playback Rate:",
					validate = function(val)
						local num = tonumber(val)
						if not num then
							return false, "Must be a valid number"
						end

						local timeRateModel = game.timeRateModel
						local replayBase = game.replayBase
						if not timeRateModel or not replayBase then
							return true
						end

						local range = timeRateModel.range[replayBase.rate_type]
						if range and (num < range[1] or num > range[2]) then
							return false, ("Rate must be between %s and %s"):format(range[1], range[2])
						end
						return true
					end
				}
			},
			callback = function(args)
				if game.timeRateModel then
					game.timeRateModel:set(args.rate)
					game.modifierSelectModel:change()
				end
			end
		}
	}
end


return M
