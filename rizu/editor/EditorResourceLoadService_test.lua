local EditorResourceLoadService = require("rizu.editor.EditorResourceLoadService")

local test = {}

---@param t testing.T
function test.load_runs_resource_steps_in_order(t)
	local calls = {}
	local resources = {
		audio = "song.ogg",
	}
	local resourcesLoaded
	local context = {
		setResourcesLoaded = function(_, loaded)
			resourcesLoaded = loaded
		end,
		loadAudioResources = function(_, loadedResources)
			table.insert(calls, "audio:" .. loadedResources.audio)
		end,
		renderWave = function()
			table.insert(calls, "wave")
		end,
		genGraphs = function()
			table.insert(calls, "graphs")
		end,
	}

	EditorResourceLoadService():load(context, resources)

	t:eq(resourcesLoaded, true)
	t:tdeq(calls, {"audio:song.ogg", "wave", "graphs"})
end

---@param t testing.T
function test.load_fails_fast_on_audio_error(t)
	local calls = {}
	local resourcesLoaded
	local context = {
		setResourcesLoaded = function(_, loaded)
			resourcesLoaded = loaded
		end,
		loadAudioResources = function()
			table.insert(calls, "audio")
			error("audio failed")
		end,
		renderWave = function()
			table.insert(calls, "wave")
		end,
		genGraphs = function()
			table.insert(calls, "graphs")
		end,
	}

	t:has_error(function()
		EditorResourceLoadService():load(context, {})
	end)

	t:eq(resourcesLoaded, nil)
	t:tdeq(calls, {"audio"})
end

---@param t testing.T
function test.load_does_not_mark_loaded_when_graphs_fail(t)
	local calls = {}
	local resourcesLoaded
	local context = {
		setResourcesLoaded = function(_, loaded)
			resourcesLoaded = loaded
		end,
		loadAudioResources = function()
			table.insert(calls, "audio")
		end,
		renderWave = function()
			table.insert(calls, "wave")
		end,
		genGraphs = function()
			table.insert(calls, "graphs")
			error("graphs failed")
		end,
	}

	t:has_error(function()
		EditorResourceLoadService():load(context, {})
	end)

	t:eq(resourcesLoaded, nil)
	t:tdeq(calls, {"audio", "wave", "graphs"})
end

return test
