local Settings = require("rizu.config.Settings")
local ColumnsOrder = require("sea.chart.ColumnsOrder")
local Subtimings = require("sea.chart.Subtimings")
local Timings = require("sea.chart.Timings")
local Subtimings = require("sea.chart.Subtimings")
local TimingValuesFactory = require("sea.chart.TimingValuesFactory")

---@return rizu.command.Fuzzy.Candidate[] choices
local function getBooleanChoices()
	return {
		{title = "Enabled", value = true},
		{title = "Disabled", value = false},
	}
end

---@param game sphere.GameController
local function updateReplayBase(game)
	game.multiplayerModel.client:updateReplayBase()
end

---@param game sphere.GameController
---@param timings sea.Timings
---@param subtimings sea.Subtimings?
local function applyTimingValues(game, timings, subtimings)
	game.replayBase.timings = timings
	game.replayBase.subtimings = subtimings

	if timings.name ~= "arbitrary" then
		game.replayBase.timing_values = assert(TimingValuesFactory:get(timings, subtimings))
	end

	updateReplayBase(game)
end

---@return rizu.command.Fuzzy.Candidate[] choices
local function getTimingChoices()
	---@type rizu.command.Fuzzy.Candidate[]
	local choices = {}
	for _, name in ipairs(Timings.names) do
		table.insert(choices, {
			title = name,
			value = name,
		})
	end
	return choices
end

---@param timeRateModel sphere.TimeRateModel
---@return rizu.command.Fuzzy.Candidate[] choices
local function getRateTypeChoices(timeRateModel)
	---@type rizu.command.Fuzzy.Candidate[]
	local choices = {}
	for _, rate_type in ipairs(timeRateModel.types) do
		table.insert(choices, {
			title = rate_type,
			value = rate_type,
		})
	end
	return choices
end

---@param game sphere.GameController
---@return sea.ColumnsOrder columns_order
local function getColumnsOrder(game)
	local replayBase = game.replayBase
	local inputMode = game.modifierCoordinator.state.inputMode
	return ColumnsOrder(inputMode, replayBase.columns_order)
end

---@param game sphere.GameController
---@param columns_order sea.ColumnsOrder
local function setColumnsOrder(game, columns_order)
	game.replayBase.columns_order = columns_order:export()
	updateReplayBase(game)
end

---@param game sphere.GameController
---@return rizu.command.Command[]
return function(game)
	return {
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

						local range = game.timeRateModel.range[game.replayBase.rate_type]
						if range and (num < range[1] or num > range[2]) then
							return false, ("Rate must be between %s and %s"):format(range[1], range[2])
						end
						return true
					end,
				},
			},
			callback = function(args)
				game.timeRateModel:set(args.rate)
				game.modifierSelectModel:change()
			end,
		},
		{
			id = "play_config.set_auto_timings",
			title = "Play Config: Set Auto Timings",
			description = "Enables or disables automatic timing selection",
			arguments = {
				{
					name = "enabled",
					type = "boolean",
					prompt = "Auto timings:",
					choices = getBooleanChoices(),
				},
			},
			callback = function(args)
				game.settings:setBoolean(Settings.keys.replay_base.auto_timings, args.enabled)
				updateReplayBase(game)
			end,
		},
		{
			id = "play_config.set_rate_type",
			title = "Play Config: Set Rate Type",
			description = "Changes the replay base rate type",
			arguments = {
				{
					name = "rate_type",
					type = "string",
					prompt = "Select rate type:",
					choices = function()
						return getRateTypeChoices(game.timeRateModel)
					end,
				},
			},
			callback = function(args)
				game.replayBase.rate_type = args.rate_type
				updateReplayBase(game)
			end,
		},
		{
			id = "play_config.set_nearest",
			title = "Play Config: Set Nearest",
			description = "Enables or disables nearest-note input behavior",
			arguments = {
				{
					name = "enabled",
					type = "boolean",
					prompt = "Nearest:",
					choices = getBooleanChoices(),
				},
			},
			callback = function(args)
				game.replayBase.nearest = args.enabled
				updateReplayBase(game)
			end,
		},
		{
			id = "play_config.set_tap_only",
			title = "Play Config: Set Tap Only",
			description = "Enables or disables tap-only behavior",
			arguments = {
				{
					name = "enabled",
					type = "boolean",
					prompt = "Tap only:",
					choices = getBooleanChoices(),
				},
			},
			callback = function(args)
				game.replayBase.tap_only = args.enabled
				updateReplayBase(game)
			end,
		},
		{
			id = "play_config.set_const",
			title = "Play Config: Set Const",
			description = "Enables or disables const mode",
			arguments = {
				{
					name = "enabled",
					type = "boolean",
					prompt = "Const:",
					choices = getBooleanChoices(),
				},
			},
			callback = function(args)
				game.replayBase.const = args.enabled
				updateReplayBase(game)
			end,
		},
		{
			id = "play_config.set_custom",
			title = "Play Config: Set Custom",
			description = "Enables or disables custom mode",
			arguments = {
				{
					name = "enabled",
					type = "boolean",
					prompt = "Custom:",
					choices = getBooleanChoices(),
				},
			},
			callback = function(args)
				game.replayBase.custom = args.enabled
				updateReplayBase(game)
			end,
		},
		{
			id = "play_config.set_timings",
			title = "Timings: Set",
			description = "Selects scoring timings",
			arguments = {
				{
					name = "timings",
					type = "string",
					prompt = "Select timings:",
					choices = getTimingChoices(),
				},
				{
					name = "data",
					type = "number",
					prompt = "Enter timing data:",
					default = 0,
				},
			},
			---@param args {timings: string, data: number}
			callback = function(args)
				local timings = Timings(args.timings, args.data)
				local subtimings ---@type sea.Subtimings?
				local timing_key = Settings.keys.timings[args.timings]
				if timing_key then
					game.settings:setNumber(timing_key, args.data)
				end

				-- TODO: I don't like that we do it here.
				if args.timings == "osuod" then
					subtimings = Subtimings("scorev", 1)
				end

				if subtimings then
					game.settings:setNumber(Settings.keys.timings.osu_score_version, subtimings.data)
				end

				applyTimingValues(game, timings, subtimings)
			end,
		},
		{
			id = "play_config.set_osu_scorev",
			title = "Timings: Set osu! Score Version",
			description = "Sets osu!mania subtiming score version",
			arguments = {
				{
					name = "version",
					type = "number",
					prompt = "Score version:",
					choices = {
						{title = "Score v1", value = 1},
						{title = "Score v2", value = 2},
					},
				},
			},
			callback = function(args)
				local replayBase = game.replayBase
				local timings = replayBase.timings or Timings("osuod", game.settings:getNumber(Settings.keys.timings.osuod))
				local subtimings = Subtimings("scorev", args.version)
				game.settings:setNumber(Settings.keys.timings.osu_score_version, args.version)
				applyTimingValues(game, timings, subtimings)
			end,
		},
		{
			id = "play_config.columns_reset",
			title = "Columns: Reset Order",
			description = "Resets the column order",
			callback = function()
				local columns_order = getColumnsOrder(game)
				columns_order:import()
				setColumnsOrder(game, columns_order)
			end,
		},
		{
			id = "play_config.columns_mirror",
			title = "Columns: Mirror",
			description = "Mirrors the column order",
			callback = function()
				setColumnsOrder(game, getColumnsOrder(game):mirror())
			end,
		},
		{
			id = "play_config.columns_shift",
			title = "Columns: Shift",
			description = "Shifts the column order",
			arguments = {
				{
					name = "amount",
					type = "number",
					prompt = "Shift amount:",
				},
			},
			callback = function(args)
				setColumnsOrder(game, getColumnsOrder(game):shift(args.amount))
			end,
		},
		{
			id = "play_config.columns_bracketswap",
			title = "Columns: Bracketswap",
			description = "Applies bracketswap column order",
			callback = function()
				setColumnsOrder(game, getColumnsOrder(game):bracketswap())
			end,
		},
		{
			id = "play_config.columns_random",
			title = "Columns: Randomize",
			description = "Randomizes the column order",
			arguments = {
				{
					name = "mode",
					type = "string",
					prompt = "Randomize mode:",
					choices = {
						{title = "All", value = ""},
						{title = "Left", value = "left"},
						{title = "Right", value = "right"},
					},
				},
			},
			callback = function(args)
				local mode = args.mode ~= "" and args.mode or nil
				setColumnsOrder(game, getColumnsOrder(game):random(mode))
			end,
		},
	}
end
