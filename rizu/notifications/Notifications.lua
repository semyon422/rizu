local class = require("class")
local Observable = require("Observable")

---@alias rizu.notifications.Kind "info"|"success"|"error"|"server"

---@class rizu.notifications.Action
---@field id string What it does, for UIs to localize: "open", "copy".
---@field label string English label.
---@field run fun()

---@class rizu.notifications.Notification
---@field id integer
---@field kind rizu.notifications.Kind
---@field type string What happened, for UIs to localize: "screenshot_saved".
---@field params table Values a localized text may use.
---@field title string English title.
---@field text string? English text.
---@field time integer os.time() of the latest post.
---@field count integer How many times the same notification was posted.
---@field actions rizu.notifications.Action[]

---@class rizu.notifications.Task
---@field id integer
---@field type string
---@field params table
---@field title string
---@field text string?
---@field done integer?
---@field total integer? nil while the amount of work is unknown.

---@class rizu.notifications.PostParams
---@field kind rizu.notifications.Kind
---@field type string
---@field params table?
---@field title string
---@field text string?
---@field actions rizu.notifications.Action[]?

---@class rizu.notifications.TaskParams
---@field type string
---@field params table?
---@field title string
---@field text string?
---@field done integer?
---@field total integer?

---@alias rizu.notifications.Event
---| {type: "posted", notification: rizu.notifications.Notification}
---| {type: "notifications_changed"}
---| {type: "unread_changed", count: integer}
---| {type: "tasks_changed"}
---| {type: "task_progress", task: rizu.notifications.Task}

---The notifications and running background tasks of this session. Main thread only.
---@class rizu.notifications.Notifications
---@operator call: rizu.notifications.Notifications
---@field notifications rizu.notifications.Notification[] Newest first.
---@field tasks rizu.notifications.Task[] Oldest first.
---@field unread integer
---@field onChanged util.Observable Sends rizu.notifications.Event.
---@field private next_id integer
---@field clock fun(): integer
local Notifications = class()

Notifications.MAX_NOTIFICATIONS = 50

---@param clock (fun(): integer)?
function Notifications:new(clock)
	self.notifications = {}
	self.tasks = {}
	self.unread = 0
	self.onChanged = Observable()
	self.next_id = 1
	self.clock = clock or os.time
end

---@private
---@return integer
function Notifications:nextId()
	local id = self.next_id
	self.next_id = id + 1
	return id
end

---@private
---@param count integer
function Notifications:setUnread(count)
	count = math.min(count, #self.notifications)
	if count == self.unread then return end
	self.unread = count
	self.onChanged:send({type = "unread_changed", count = count})
end

---Posts a notification. The same one posted again moves to the top with its count raised.
---@param p rizu.notifications.PostParams
---@return rizu.notifications.Notification
function Notifications:post(p)
	assert(p.kind and p.type and p.title, "a notification needs kind, type and title")
	local list = self.notifications
	local notification ---@type rizu.notifications.Notification?
	for i, n in ipairs(list) do
		if n.kind == p.kind and n.type == p.type and n.title == p.title and n.text == p.text then
			notification = table.remove(list, i)
			break
		end
	end
	if notification then
		notification.count = notification.count + 1
		notification.time = self.clock()
		notification.params = p.params or {}
		notification.actions = p.actions or {}
	else
		notification = {
			id = self:nextId(),
			kind = p.kind,
			type = p.type,
			params = p.params or {},
			title = p.title,
			text = p.text,
			time = self.clock(),
			count = 1,
			actions = p.actions or {},
		}
	end
	table.insert(list, 1, notification)
	list[self.MAX_NOTIFICATIONS + 1] = nil
	self.onChanged:send({type = "posted", notification = notification})
	self.onChanged:send({type = "notifications_changed"})
	self:setUnread(self.unread + 1)
	return notification
end

---@param id integer
---@return rizu.notifications.Notification?
---@return integer? index
function Notifications:find(id)
	for i, n in ipairs(self.notifications) do
		if n.id == id then return n, i end
	end
end

---@param id integer
function Notifications:dismiss(id)
	local _, index = self:find(id)
	if not index then return end
	table.remove(self.notifications, index)
	self.onChanged:send({type = "notifications_changed"})
	self:setUnread(self.unread)
end

function Notifications:clear()
	if #self.notifications == 0 then return end
	self.notifications = {}
	self.onChanged:send({type = "notifications_changed"})
	self:setUnread(0)
end

function Notifications:markRead()
	self:setUnread(0)
end

---@param id integer
---@param index integer
function Notifications:runAction(id, index)
	local notification = self:find(id)
	local action = notification and notification.actions[index]
	if action then action.run() end
end

---@param p rizu.notifications.TaskParams
---@return rizu.notifications.Task
function Notifications:startTask(p)
	assert(p.type and p.title, "a task needs type and title")
	local task = {
		id = self:nextId(),
		type = p.type,
		params = p.params or {},
		title = p.title,
		text = p.text,
		done = p.done,
		total = p.total,
	}
	table.insert(self.tasks, task)
	self.onChanged:send({type = "tasks_changed"})
	return task
end

---@param task rizu.notifications.Task
---@param done integer?
---@param total integer?
function Notifications:progressTask(task, done, total)
	if task.done == done and task.total == total then return end
	task.done, task.total = done, total
	self.onChanged:send({type = "task_progress", task = task})
end

---@param task rizu.notifications.Task
function Notifications:endTask(task)
	for i, t in ipairs(self.tasks) do
		if t == task then
			table.remove(self.tasks, i)
			self.onChanged:send({type = "tasks_changed"})
			return
		end
	end
end

return Notifications
