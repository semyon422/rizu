local Events = require("rizu.api.Events")

--[[
Notifications for the player and the background tasks that are running.

	local notifications = ui.api.notifications
	bell:setBadge(notifications:getUnreadCount())
	for i = 1, notifications:getCount() do
		local n = notifications:getNotification(i)
		drawRow(localize(n.type, n.params) or n.title, n.text, n.time)
	end
	notifications:on("posted", function(n) showToast(n.title) end)

A notification's `type` says what happened ("screenshot_saved"), its `params` hold the values a translated text
needs, and `title`/`text` are English for UIs that do not translate that type. The same notification posted again
moves to the top and counts up. Only this session's notifications are kept, at most 50.
]]

---@alias rizu.api.Notifications.Event
---| "posted" # A notification was posted or posted again. Arguments: the rizu.api.Notification.
---| "notifications_changed" # The list changed. No arguments.
---| "unread_changed" # getUnreadCount() changed. Arguments: count.
---| "tasks_changed" # A task started or ended. No arguments.
---| "task_progress" # A task moved on. Arguments: the rizu.api.Task.

---A button under a notification: pass its index to runAction().
---@class rizu.api.NotificationAction
---@field id string What it does, to translate the label: "open", "copy".
---@field label string English label.

---The game's own table: read it, do not change it.
---@class rizu.api.Notification
---@field id integer
---@field kind "info"|"success"|"error"|"server"
---@field type string What happened, to translate the title and text.
---@field params table Values the translated text may use.
---@field title string English title.
---@field text string? English text.
---@field time integer os.time() of the latest post.
---@field count integer How many times it was posted.
---@field actions rizu.api.NotificationAction[]

---A background task. The game's own table: read it, do not change it. done and total change while it runs.
---@class rizu.api.Task
---@field id integer
---@field type string What it does, to translate the title and text.
---@field params table
---@field title string English title.
---@field text string? English text.
---@field done integer?
---@field total integer? nil while the amount of work is unknown: show it as busy.

---@class rizu.api.Notifications : rizu.api.Events
---@operator call: rizu.api.Notifications
---@field on fun(self: rizu.api.Notifications, event: rizu.api.Notifications.Event, f: function): fun()
---@field private core rizu.notifications.Notifications
local Notifications = Events + {}

local forwarded = {
	notifications_changed = true,
	tasks_changed = true,
}

---@param core rizu.notifications.Notifications
function Notifications:new(core)
	Events.new(self)
	self.core = core
	core.onChanged:add(function(event)
		if event.type == "posted" then
			self:emit("posted", event.notification)
		elseif event.type == "unread_changed" then
			self:emit("unread_changed", event.count)
		elseif event.type == "task_progress" then
			self:emit("task_progress", event.task)
		elseif forwarded[event.type] then
			self:emit(event.type)
		end
	end)
end

---@return integer
function Notifications:getCount() return #self.core.notifications end

---Newest first.
---@param i integer
---@return rizu.api.Notification?
function Notifications:getNotification(i) return self.core.notifications[i] --[[@as rizu.api.Notification?]] end

---Notifications posted since markRead().
---@return integer
function Notifications:getUnreadCount() return self.core.unread end

---Call it when the player has seen the list.
function Notifications:markRead() self.core:markRead() end

---@param id integer
function Notifications:dismiss(id) self.core:dismiss(id) end

function Notifications:clear() self.core:clear() end

---@param id integer The notification's id.
---@param index integer Index in its actions.
function Notifications:runAction(id, index) self.core:runAction(id, index) end

---@return integer
function Notifications:getTaskCount() return #self.core.tasks end

---Oldest first.
---@param i integer
---@return rizu.api.Task?
function Notifications:getTask(i) return self.core.tasks[i] --[[@as rizu.api.Task?]] end

return Notifications
