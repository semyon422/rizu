local Observable = require("Observable")
local Events = require("rizu.api.Events")
local Notifications = require("rizu.notifications.Notifications")
local NotificationsApi = require("rizu.api.Notifications")
local GameNotifications = require("rizu.notifications.GameNotifications")

local test = {}

---@param t testing.T
function test.library_stage_is_a_task_and_errors_are_grouped(t)
	local n = Notifications()
	local library = {status = {stage = "idle"}, errors = {}, onStatusChanged = Observable(), onLocationScanned = Observable(), onTaskFailed = Observable()}
	GameNotifications.connectLibrary(n, library --[[@as any]])

	library.onStatusChanged:send({stage = "hashing", current = 1, total = 0})
	t:eq(n.tasks[1].type, "library_hashing")
	t:eq(n.tasks[1].total, nil)
	library.errors[1], library.errors[2] = "bad 1", "bad 2"
	library.onStatusChanged:send({stage = "hashing", current = 5, total = 10})
	t:eq(n.tasks[1].done, 5)
	t:eq(#n.notifications, 0)

	library.onStatusChanged:send({stage = "idle", current = 0, total = 0})
	t:eq(#n.tasks, 0)
	t:eq(#n.notifications, 1)
	t:eq(n.notifications[1].params.count, 2)
	t:eq(n.notifications[1].text, "bad 2")
end

---@param t testing.T
function test.ended_location_scan_is_posted_with_its_charts(t)
	local n = Notifications()
	local info = {} ---@type {[integer]: {chartfiles: integer}}
	local library = {
		status = {stage = "idle"},
		errors = {},
		onStatusChanged = Observable(),
		onLocationScanned = Observable(),
		onTaskFailed = Observable(),
		locationsRepo = {selectLocationById = function(_, id) return {id = id, name = "Songs"} end},
		locations = {info = info, updateLocationInfo = function(_, id) info[id] = {chartfiles = 12} end},
	}
	GameNotifications.connectLibrary(n, library --[[@as any]])

	library.onLocationScanned:send({location_id = 4, stopped = false})
	t:eq(n.notifications[1].type, "location_scanned")
	t:tdeq(n.notifications[1].params, {name = "Songs", count = 12})
	library.onLocationScanned:send({location_id = 4, stopped = true})
	t:eq(#n.notifications, 2)
	local stopped = n.notifications[1].type == "location_scan_stopped" and n.notifications[1] or n.notifications[2]
	t:eq(stopped.type, "location_scan_stopped")
end

---@param t testing.T
function test.failed_task_is_posted_once(t)
	local n = Notifications()
	local library = {
		status = {stage = "idle"},
		errors = {},
		onStatusChanged = Observable(),
		onLocationScanned = Observable(),
		onTaskFailed = Observable(),
		locationsRepo = {selectLocationById = function(_, id) return {id = id, name = "Drive"} end},
	}
	GameNotifications.connectLibrary(n, library --[[@as any]])

	library.onTaskFailed:send({location_id = 2, error = "Folder not found: /mnt/drive\ntraceback"})
	library.onLocationScanned:send({location_id = 2, stopped = false, failed = true})
	t:eq(#n.notifications, 1)
	t:eq(n.notifications[1].type, "location_scan_failed")
	t:eq(n.notifications[1].text, "Folder not found: /mnt/drive")

	library.onTaskFailed:send({error = "boom"})
	t:eq(n.notifications[1].type, "library_task_failed")
end

---@param t testing.T
function test.failing_listener_is_posted_once(t)
	local n = Notifications()
	local charts = Events()
	local api = {charts = charts, notifications = NotificationsApi(n)}
	GameNotifications.connectApi(n, api --[[@as any]])
	-- Fails on every post, so reporting it must not post again.
	api.notifications:on("posted", function() error("listener of posted") end)

	charts:on("x", function() error("boom") end)
	charts:emit("x")
	t:eq(#n.notifications, 1)
	t:eq(n.notifications[1].type, "listener_error")
	t:assert(n.notifications[1].text:find("boom", 1, true))
end

return test
