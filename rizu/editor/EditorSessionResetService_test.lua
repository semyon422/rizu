local EditorSessionResetService = require("rizu.editor.EditorSessionResetService")

local test = {}

---@param t testing.T
function test.reset_initializes_editor_session_state(t)
	local calls = {}
	local changes
	local chart = {}
	local context = {
		getAnalysisState = function()
			return {
				analyze = function(_, loadedChart)
					table.insert(calls, "analysis")
					t:eq(loadedChart, chart)
				end,
			}
		end,
		getChart = function()
			return chart
		end,
		setChanges = function(_, loadedChanges)
			table.insert(calls, "changes")
			changes = loadedChanges
		end,
		getGraphsGenerator = function()
			return {
				load = function()
					table.insert(calls, "graphs")
				end,
			}
		end,
		setResourcesLoaded = function(_, loaded)
			table.insert(calls, "resources:" .. tostring(loaded))
		end,
		setSessionTime = function(_, time)
			table.insert(calls, "time:" .. time)
		end,
		getSelectionState = function()
			return {
				finish = function()
					table.insert(calls, "selection")
				end,
			}
		end,
	}

	EditorSessionResetService():reset(context)

	t:ne(changes, nil)
	t:tdeq(calls, {
		"analysis",
		"changes",
		"graphs",
		"resources:false",
		"time:0",
		"selection",
	})
end

return test
