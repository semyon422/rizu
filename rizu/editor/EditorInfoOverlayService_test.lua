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
function test.edit_metadata_applies_callback_results(t)
	local calls = {}
	local metadata = {
		title = "Song",
		artist = "Artist",
	}
	local context = createContext({
		calls = calls,
		metadata = metadata,
		keys = {"title", "artist"},
	})

	EditorInfoOverlayService():editMetadata(context, function(key, value)
		return value .. ":" .. key
	end)

	t:eq(metadata.title, "Song:title")
	t:eq(metadata.artist, "Artist:artist")
	t:tdeq(calls, {"metadata:title=Song:title", "metadata:artist=Artist:artist"})
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
