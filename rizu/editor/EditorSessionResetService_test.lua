local EditorSessionResetService = require("rizu.editor.EditorSessionResetService")

local test = {}

---@param t testing.T
function test.reset_initializes_editor_session_state(t)
	local calls = {}
	local selectionState = {
		finish = function()
			table.insert(calls, "selection")
		end,
	}
	local changes
	local editorModel = {
		graphsGenerator = {
			load = function()
				table.insert(calls, "graphs")
			end,
		},
		analyzePatterns = function()
			table.insert(calls, "analysis")
		end,
		setChanges = function(_, nextChanges)
			table.insert(calls, "changes")
			changes = nextChanges
		end,
		setResourcesLoaded = function(_, loaded)
			table.insert(calls, "resources:" .. tostring(loaded))
		end,
		setSessionTime = function(_, time)
			table.insert(calls, "time:" .. time)
		end,
		getSelectionState = function()
			return selectionState
		end,
		syncSessionAliases = function()
			table.insert(calls, "sync")
		end,
	}

	EditorSessionResetService():reset(editorModel)

	t:ne(changes, nil)
	t:tdeq(calls, {
		"analysis",
		"changes",
		"graphs",
		"resources:false",
		"time:0",
		"selection",
		"sync",
	})
end

return test
