local SelectionCoordinator = require("rizu.select.SelectionCoordinator")

local test = {}

---@class rizu.select.FakeSelectionObserver
---@field receive (fun(self: rizu.select.FakeSelectionObserver, event: table))?

---@alias rizu.select.FakeSelectionEventReceiver rizu.select.FakeSelectionObserver|fun(event: table)

---@param calls string[]
---@return rizu.select.SelectionCoordinator
local function newCoordinator(calls)
	---@type rizu.select.FakeSelectionEventReceiver[]
	local chart_observers = {}
	local chartSelector = {
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
		isPlayableChartview = function(_, chartview)
			return chartview and chartview.title ~= nil
		end,
	}
	return SelectionCoordinator(
		chartSelector,
		{},
		{
			onChanged = function() end,
		},
		{},
		{
			load = function()
				table.insert(calls, "preview-load")
			end,
		}
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

---@param t testing.T
function test.provisional_chartview_changed_does_not_activate_preview(t)
	local calls = {}
	local coordinator = newCoordinator(calls)

	coordinator.chartSelector:emit({type = "chartview_changed", chartview = {chartfile_id = 1}})

	t:tdeq(calls, {})
end

---@param t testing.T
function test.update_clears_preview_for_provisional_chartview(t)
	local calls = {}
	local coordinator = newCoordinator(calls)
	coordinator.chartSelector.chartview = {chartfile_id = 1}
	coordinator.chartSelector.isChanged = function()
		return true
	end
	coordinator.chartSelector.getBackgroundPath = function()
		return nil
	end
	coordinator.chartSelector.getAudioPathPreview = function()
		return nil
	end
	coordinator.backgroundModel.setBackgroundPath = function(_, path)
		table.insert(calls, "background:" .. tostring(path))
	end
	coordinator.previewModel.setAudioPathPreview = function(_, path, preview_time, mode, chartview)
		table.insert(calls, "preview:" .. tostring(path) .. ":" .. tostring(chartview.chartfile_id))
	end
	local applied = false

	coordinator:update(function()
		applied = true
	end)

	t:tdeq(calls, {
		"background:nil",
		"preview:nil:1",
	})
	t:eq(applied, true)
end

---@param t testing.T
function test.update_without_selection_change_does_nothing(t)
	local calls = {}
	local coordinator = newCoordinator(calls)
	coordinator.chartSelector.isChanged = function()
		return false
	end

	coordinator:update()

	t:tdeq(calls, {})
end

return test
