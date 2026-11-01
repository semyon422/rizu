local Notifications = require("rizu.notifications.Notifications")

local test = {}

---@return rizu.notifications.Notifications
---@return table[] events
local function create()
	local now = 100
	local n = Notifications(function() now = now + 1; return now end)
	local events = {}
	n.onChanged:add(function(e) events[#events + 1] = e end) ---@diagnostic disable-line: no-unknown
	return n, events
end

---@param t testing.T
function test.post_dismiss_and_unread(t)
	local n, events = create()
	local a = n:post({kind = "info", type = "a", title = "A"})
	local b = n:post({kind = "error", type = "b", title = "B", text = "x"})
	t:eq(n.notifications[1], b)
	t:eq(n.unread, 2)
	t:eq(events[1].type, "posted")
	t:eq(events[3].type, "unread_changed")

	n:dismiss(b.id)
	t:eq(n.notifications[1], a)
	t:eq(n.unread, 1)
	n:markRead()
	t:eq(n.unread, 0)
	n:clear()
	t:eq(#n.notifications, 0)
end

---@param t testing.T
function test.same_post_is_counted_and_moved_up(t)
	local n = create()
	local a = n:post({kind = "error", type = "e", title = "E", text = "same"})
	n:post({kind = "info", type = "i", title = "I"})
	local again = n:post({kind = "error", type = "e", title = "E", text = "same"})
	t:eq(again, a)
	t:eq(a.count, 2)
	t:eq(n.notifications[1], a)
	t:eq(#n.notifications, 2)
end

---@param t testing.T
function test.list_is_capped(t)
	local n = create()
	for i = 1, Notifications.MAX_NOTIFICATIONS + 5 do
		n:post({kind = "info", type = "i", title = tostring(i)})
	end
	t:eq(#n.notifications, Notifications.MAX_NOTIFICATIONS)
	t:eq(n.notifications[1].title, tostring(Notifications.MAX_NOTIFICATIONS + 5))
	t:eq(n.unread, Notifications.MAX_NOTIFICATIONS)
end

---@param t testing.T
function test.actions_run_by_index(t)
	local n = create()
	local ran = false
	local a = n:post({kind = "success", type = "s", title = "S",
		actions = {{id = "open", label = "Open", run = function() ran = true end}}})
	n:runAction(a.id, 2)
	t:eq(ran, false)
	n:runAction(a.id, 1)
	t:eq(ran, true)
end

---@param t testing.T
function test.task_lifecycle(t)
	local n, events = create()
	local task = n:startTask({type = "scan", title = "Scan"})
	t:eq(n.tasks[1], task)
	n:progressTask(task, 1, 10)
	n:progressTask(task, 1, 10)
	n:endTask(task)
	t:eq(#n.tasks, 0)
	local types = {} ---@type string[]
	for _, e in ipairs(events) do types[#types + 1] = e.type end ---@diagnostic disable-line: no-unknown
	t:eq(table.concat(types, " "), "tasks_changed task_progress tasks_changed")
end

return test
