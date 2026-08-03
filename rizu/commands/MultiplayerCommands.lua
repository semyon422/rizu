local ChartmetaKey = require("sea.chart.ChartmetaKey")

---@param value string
---@return boolean valid
---@return string? error_msg
local function validateNotEmpty(value)
	if value == "" then
		return false, "Value cannot be empty"
	end
	return true
end

---@param game sphere.GameController
---@return sea.ChartmetaKey? chartmeta_key
local function getSelectedChartmetaKey(game)
	local chartview = game.chartSelector.chartview
	if not chartview or not chartview.hash or not chartview.index then
		return
	end

	local chartmeta_key = ChartmetaKey()
	chartmeta_key.hash = chartview.hash
	chartmeta_key.index = chartview.index
	return chartmeta_key
end

---@param game sphere.GameController
---@return rizu.command.Fuzzy.Candidate[] choices
local function getRoomChoices(game)
	---@type rizu.command.Fuzzy.Candidate[]
	local choices = {}
	for _, room in ipairs(game.multiplayerModel.client.rooms) do
		local title = room.name
		if room.isPlaying then
			title = title .. " (playing)"
		end
		table.insert(choices, {
			title = title,
			value = room.id,
		})
	end
	return choices
end

---@param game sphere.GameController
---@return rizu.command.Command[]
return function(game)
	local multiplayerModel = game.multiplayerModel
	local client = multiplayerModel.client

	return {
		{
			id = "multiplayer.create_room",
			title = "Multiplayer: Create Room",
			description = "Creates a room using the selected chart",
			arguments = {
				{
					name = "name",
					type = "string",
					prompt = "Room name:",
					validate = validateNotEmpty,
				},
				{
					name = "password",
					type = "string",
					prompt = "Room password:",
				},
			},
			callback = function(args)
				local chartmeta_key = getSelectedChartmetaKey(game)
				if chartmeta_key then
					client:createRoom(args.name, args.password, chartmeta_key)
				end
			end,
		},
		{
			id = "multiplayer.join_room",
			title = "Multiplayer: Join Room",
			description = "Joins a multiplayer room",
			arguments = {
				{
					name = "room_id",
					type = "number",
					prompt = "Select room:",
					choices = function()
						return getRoomChoices(game)
					end,
				},
				{
					name = "password",
					type = "string",
					prompt = "Room password:",
				},
			},
			callback = function(args)
				client:joinRoom(args.room_id, args.password)
			end,
		},
		{
			id = "multiplayer.leave_room",
			title = "Multiplayer: Leave Room",
			description = "Leaves the current multiplayer room",
			callback = function()
				client:leaveRoom()
			end,
		},
		{
			id = "multiplayer.ready",
			title = "Multiplayer: Toggle Ready",
			description = "Toggles your ready state",
			callback = function()
				client:switchReady()
			end,
		},
		{
			id = "multiplayer.start_match",
			title = "Multiplayer: Start Match",
			description = "Starts the current room match",
			callback = function()
				client:startMatch()
			end,
		},
		{
			id = "multiplayer.stop_match",
			title = "Multiplayer: Stop Match",
			description = "Stops the current room match",
			callback = function()
				client:stopMatch()
			end,
		},
		{
			id = "multiplayer.send_message",
			title = "Multiplayer: Send Message",
			description = "Sends a room chat message",
			arguments = {
				{
					name = "message",
					type = "string",
					prompt = "Message:",
					validate = validateNotEmpty,
				},
			},
			callback = function(args)
				client:sendMessage(args.message)
			end,
		},
		{
			id = "multiplayer.set_selected_chart",
			title = "Multiplayer: Set Selected Chart",
			description = "Sets the room chart to the selected chart",
			callback = function()
				local chartmeta_key = getSelectedChartmetaKey(game)
				if chartmeta_key then
					client:updateChartmetaKey(chartmeta_key)
				end
			end,
		},
		{
			id = "multiplayer.update_replay_base",
			title = "Multiplayer: Sync Play Config",
			description = "Syncs the current replay base to the multiplayer room",
			callback = function()
				client:updateReplayBase()
			end,
		},
		{
			id = "multiplayer.download_chart",
			title = "Multiplayer: Download Room Chart",
			description = "Downloads the current room chart when available",
			callback = function()
				multiplayerModel:downloadNoteChart()
			end,
		},
	}
end
