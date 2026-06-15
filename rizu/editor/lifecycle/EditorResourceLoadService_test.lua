local EditorResourceLoadService = require("rizu.editor.lifecycle.EditorResourceLoadService")

local test = {}

---@param t testing.T
function test.load_runs_resource_steps_in_order(t)
	local calls = {}
	local resources = {
		audio = "song.ogg",
	}
	local resourcesLoaded
	local context = {
		getPlaybackService = function()
			return {
				loadEditorAudioResources = function(_, _playbackContext, loadedResources)
					table.insert(calls, "audio:" .. loadedResources.audio)
				end,
			}
		end,
		getPlaybackContext = function()
			return "playback"
		end,
		getAnalysisService = function()
			return {
				renderWave = function()
					table.insert(calls, "wave")
				end,
				genGraphs = function()
					table.insert(calls, "graphs")
				end,
			}
		end,
		getAnalysisContext = function()
			return "analysis"
		end,
		setResourcesLoaded = function(_, loaded)
			resourcesLoaded = loaded
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
		getPlaybackService = function()
			return {
				loadEditorAudioResources = function()
					table.insert(calls, "audio")
					error("audio failed")
				end,
			}
		end,
		getPlaybackContext = function()
			return "playback"
		end,
		getAnalysisService = function()
			return {
				renderWave = function()
					table.insert(calls, "wave")
				end,
				genGraphs = function()
					table.insert(calls, "graphs")
				end,
			}
		end,
		getAnalysisContext = function()
			return "analysis"
		end,
		setResourcesLoaded = function(_, loaded)
			resourcesLoaded = loaded
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
		getPlaybackService = function()
			return {
				loadEditorAudioResources = function()
					table.insert(calls, "audio")
				end,
			}
		end,
		getPlaybackContext = function()
			return "playback"
		end,
		getAnalysisService = function()
			return {
				renderWave = function()
					table.insert(calls, "wave")
				end,
				genGraphs = function()
					table.insert(calls, "graphs")
					error("graphs failed")
				end,
			}
		end,
		getAnalysisContext = function()
			return "analysis"
		end,
		setResourcesLoaded = function(_, loaded)
			resourcesLoaded = loaded
		end,
	}

	t:has_error(function()
		EditorResourceLoadService():load(context, {})
	end)

	t:eq(resourcesLoaded, nil)
	t:tdeq(calls, {"audio", "wave", "graphs"})
end

return test
