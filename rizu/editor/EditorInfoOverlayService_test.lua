local EditorInfoOverlayService = require("rizu.editor.EditorInfoOverlayService")

local test = {}

local function createContext(fields)
	return {
		iterMetadata = function()
			local index = 0
			local keys = fields.keys
			return function()
				index = index + 1
				local key = keys[index]
				if not key then
					return nil
				end
				return key, fields.metadata[key]
			end
		end,
		setMetadata = function(_, key, value)
			fields.metadata[key] = value
			table.insert(fields.calls, "metadata:" .. key .. "=" .. value)
		end,
		save = function()
			table.insert(fields.calls, "save")
		end,
		saveToOsu = function()
			table.insert(fields.calls, "osu")
		end,
		saveToNanoChart = function()
			table.insert(fields.calls, "nano")
		end,
	}
end

---@param t testing.T
function test.get_state_returns_metadata_fields(t)
	local metadata = {
		title = "Song",
		artist = "Artist",
	}
	local state = EditorInfoOverlayService():getState(createContext({
		calls = {},
		metadata = metadata,
		keys = {"title", "artist"},
	}))

	t:eq(state.title, "Chart info")
	t:tdeq(state.fields, {
		{
			key = "title",
			value = "Song",
			inputId = "title input",
		},
		{
			key = "artist",
			value = "Artist",
			inputId = "artist input",
		},
	})
	t:tdeq(state.developmentLabels, {
		"The editor",
		"is in development",
	})
end

---@param t testing.T
function test.handle_input_updates_metadata_and_runs_save_commands(t)
	local calls = {}
	local metadata = {
		title = "Song",
	}
	local context = createContext({
		calls = calls,
		metadata = metadata,
		keys = {"title"},
	})

	EditorInfoOverlayService():handleInput(context, {
		metadata = {
			title = "New Song",
		},
		savePressed = true,
		saveToOsuPressed = true,
		saveToNanoChartPressed = true,
	})

	t:eq(metadata.title, "New Song")
	t:tdeq(calls, {
		"metadata:title=New Song",
		"save",
		"osu",
		"nano",
	})
end

---@param t testing.T
function test.save_commands_delegate_to_context(t)
	local calls = {}
	local service = EditorInfoOverlayService()
	local context = createContext({
		calls = calls,
		metadata = {},
		keys = {},
	})

	service:save(context)
	service:saveToOsu(context)
	service:saveToNanoChart(context)

	t:tdeq(calls, {"save", "osu", "nano"})
end

return test
