local EditorSessionResetService = require("rizu.editor.EditorSessionResetService")

local test = {}

---@param t testing.T
function test.reset_initializes_editor_session_state(t)
	local calls = {}
	local changes
	local nextChanges = {}
	local context = {
		analyzePatterns = function()
			table.insert(calls, "analysis")
		end,
		newChanges = function()
			table.insert(calls, "new-changes")
			return nextChanges
		end,
		setChanges = function(loadedChanges)
			table.insert(calls, "changes")
			changes = loadedChanges
		end,
		loadGraphs = function()
			table.insert(calls, "graphs")
		end,
		setResourcesLoaded = function(loaded)
			table.insert(calls, "resources:" .. tostring(loaded))
		end,
		setSessionTime = function(time)
			table.insert(calls, "time:" .. time)
		end,
		finishSelection = function()
			table.insert(calls, "selection")
		end,
	}

	EditorSessionResetService():reset(context)

	t:eq(changes, nextChanges)
	t:tdeq(calls, {
		"analysis",
		"new-changes",
		"changes",
		"graphs",
		"resources:false",
		"time:0",
		"selection",
	})
end

return test
