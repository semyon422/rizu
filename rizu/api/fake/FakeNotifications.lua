local Notifications = require("rizu.api.Notifications")
local Core = require("rizu.notifications.Notifications")

---`rizu.api.Notifications` on the real store, filled with one of each kind and two tasks.
---The caching task moves on in update() and ends.
---@class rizu.api.fake.FakeNotifications : rizu.api.Notifications
---@operator call: rizu.api.fake.FakeNotifications
---@field store rizu.notifications.Notifications
---@field caching rizu.notifications.Task?
---@field step_time number
local FakeNotifications = Notifications + {}

local STEP_INTERVAL = 0.2
local STEP_CHARTS = 137

function FakeNotifications:new()
	local now = os.time()
	local time = now
	local store = Core(function() return time end)
	Notifications.new(self, store)
	self.store = store

	time = now - 3600
	store:post({kind = "info", type = "logged_in", params = {name = "Player"}, title = "Logged in",
		text = "Welcome back, Player!"})
	time = now - 900
	store:post({kind = "server", type = "server_message", title = "Server message",
		text = "Scheduled maintenance at 03:00 UTC. Score submission will be unavailable for ~20 minutes."})
	time = now - 120
	store:post({kind = "success", type = "screenshot_saved", title = "Screenshot saved",
		actions = {{id = "open", label = "Open", run = function() end}}})
	time = now
	store:post({kind = "error", type = "listener_error", title = "Interface error",
		text = "attempt to index a nil value (field 'chartview')",
		actions = {{id = "copy", label = "Copy details", run = function() end}}})
	store.clock = os.time

	self.caching = store:startTask({type = "library_scanning", title = "Scanning charts", done = 4210, total = 10024})
	store:startTask({type = "library_hits", title = "Preparing scores for rescoring"})
	self.step_time = 0
end

---@param dt number
function FakeNotifications:update(dt)
	local task = self.caching
	if not task then return end
	self.step_time = self.step_time + dt
	if self.step_time < STEP_INTERVAL then return end
	self.step_time = 0
	self.store:progressTask(task, math.min(task.total, task.done + STEP_CHARTS), task.total)
	if task.done == task.total then
		self.store:endTask(task)
		self.caching = nil
	end
end

return FakeNotifications
