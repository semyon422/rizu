local EditorOverlayShellService = require("rizu.editor.view.overlays.EditorOverlayShellService")

local test = {}

local function createContext(fields)
	return {
		getViewState = function()
			return {
				getOverlayState = function()
					return fields.activeTab
				end,
				setOverlayState = function(_, tab)
					fields.activeTab = tab
					table.insert(fields.calls, "tab:" .. tab)
				end,
			}
		end,
		getOverlayTabs = function()
			return fields.tabs
		end,
		isResourcesLoaded = function()
			return fields.resourcesLoaded
		end,
	}
end

---@param t testing.T
function test.get_state_reads_tabs_and_resource_state(t)
	local tabs = {"info", "audio"}
	local context = createContext({
		calls = {},
		activeTab = "audio",
		tabs = tabs,
		resourcesLoaded = false,
	})

	local state = EditorOverlayShellService():getState(context)

	t:eq(state.activeTab, "audio")
	t:eq(state.tabs, tabs)
	t:eq(state.resourcesLoaded, false)
end

---@param t testing.T
function test.handle_input_updates_active_tab(t)
	local calls = {}
	local context = createContext({
		calls = calls,
		activeTab = "info",
		tabs = {},
		resourcesLoaded = true,
	})

	EditorOverlayShellService():handleInput(context, {
		activeTab = "timings",
	})

	t:eq(context:getViewState():getOverlayState(), "timings")
	t:tdeq(calls, {"tab:timings"})
end

return test
