local SelectionCoordinator = require("rizu.select.SelectionCoordinator")

local test = {}

local function newCoordinator(calls)
	local chart_observers = {}
	return SelectionCoordinator(
		{
			state = {
				onChanged = function() end,
			},
			onChanged = function(_, observer)
				table.insert(chart_observers, observer)
			end,
			emit = function(_, event)
				for _, observer in ipairs(chart_observers) do
					if type(observer) == "function" then
						observer(event)
					elseif observer.receive then
						observer:receive(event)
					end
				end
			end,
			load = function()
				table.insert(calls, "chart-load")
			end,
			setChanged = function()
				table.insert(calls, "changed")
			end,
			setLock = function(_, value)
				table.insert(calls, "lock:" .. tostring(value))
			end,
		},
		{},
		{
			onChanged = function() end,
		},
		{},
		{
			load = function()
				table.insert(calls, "preview-load")
			end,
		},
		{}
	)
end

---@param t testing.T
function test.activate_preview_loads_preview_and_marks_selection_changed(t)
	local calls = {}
	local coordinator = newCoordinator(calls)

	coordinator:activatePreview()

	t:tdeq(calls, {
		"preview-load",
		"changed",
	})
end

---@param t testing.T
function test.load_waits_for_chartview_changed_to_start_preview(t)
	local calls = {}
	local coordinator = newCoordinator(calls)

	coordinator:load()

	t:tdeq(calls, {
		"lock:false",
		"chart-load",
	})
end

---@param t testing.T
function test.chartview_changed_activates_preview_after_async_selection_load(t)
	local calls = {}
	local coordinator = newCoordinator(calls)

	coordinator.chartSelector:emit({type = "chartview_changed", chartview = {title = "song"}})

	t:tdeq(calls, {
		"preview-load",
		"changed",
	})
end

---@param t testing.T
function test.empty_chartview_changed_does_not_activate_preview(t)
	local calls = {}
	local coordinator = newCoordinator(calls)

	coordinator.chartSelector:emit({type = "chartview_changed"})

	t:tdeq(calls, {})
end

return test
