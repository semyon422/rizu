local FlowContainer = require("gui.layout.FlowContainer")
local NotificationItem = require("ui.modals.notifications.NotificationItem")

---Running tasks and fresh notifications in a corner, for screens without a notifications button.
---Clicking a card opens the notification panel.
---@class ui.views.NotificationToasts : gui.layout.FlowContainer
---@operator call: ui.views.NotificationToasts
---@field api rizu.api.Notifications
---@field localization ui.localization.Localization
---@field is_allowed fun(): boolean
---@field on_open fun()
---@field toasts {[ui.modals.notifications.NotificationItem]: number} Seconds left on screen.
---@field private unsubscribe fun()
local NotificationToasts = FlowContainer + {}

local WIDTH = 380
local TOAST_SECONDS = 5
local MAX_TOASTS = 3
local GLIDE = {duration = 0.25, easing = "OutCubic"}

local function noop() end

---@param api rizu.api.Notifications
---@param localization ui.localization.Localization
---@param is_allowed fun(): boolean False hides everything: during gameplay, or where a bell already shows it.
---@param on_open fun()
function NotificationToasts:new(api, localization, is_allowed, on_open)
	FlowContainer.new(self, {direction = "column", gap = 10, layout_transition = GLIDE})
	self.api = api
	self.localization = localization
	self.is_allowed = is_allowed
	self.on_open = on_open
	self.toasts = {}
	self:setWidth(WIDTH)
	self.unsubscribe = api:on("posted", function(notification)
		if self.is_allowed() then self:showToast(notification) end
	end)
end

function NotificationToasts:unload()
	self.unsubscribe()
end

---@private
---@param notification rizu.api.Notification?
---@param task rizu.api.Task?
---@return ui.modals.notifications.NotificationItem
function NotificationToasts:createItem(notification, task)
	local item = NotificationItem(WIDTH, self.localization, notification, task,
		function(item) self:hideItem(item) end,
		function(item, index) self.api:runAction(item.notification.id, index) end)
	item.on_click = function() self.on_open() end
	item:setOffset(40, 0):setOpacity(0)
	item:moveTo(0, 0, 0.3, "OutQuint")
	item:fadeIn(0.3, "OutCubic")
	return item
end

---@private
---@param item ui.modals.notifications.NotificationItem
function NotificationToasts:hideItem(item)
	self.toasts[item] = nil
	item:leave(noop)
end

---A notification posted again restarts its toast instead of adding one.
---@param notification rizu.api.Notification
function NotificationToasts:showToast(notification)
	local oldest, oldest_time ---@type ui.modals.notifications.NotificationItem?, number
	local count = 0
	for item, time in pairs(self.toasts) do
		if item.notification == notification then
			self.toasts[item] = TOAST_SECONDS
			return
		end
		count = count + 1
		if not oldest or time < oldest_time then oldest, oldest_time = item, time end
	end
	if oldest and count >= MAX_TOASTS then self:hideItem(oldest) end
	self.toasts[self:add(self:createItem(notification))] = TOAST_SECONDS
end

---Removes every card at once, as when the panel opens or the screen hides them.
function NotificationToasts:clearAll()
	self.toasts = {}
	self:clear()
end

---Keeps one card per running task above the toasts.
---@private
function NotificationToasts:syncTasks()
	local api = self.api
	local live, shown = {}, {} ---@type {[rizu.api.Task]: true}, {[rizu.api.Task]: true}
	for i = 1, api:getTaskCount() do
		local task = api:getTask(i) --[[@as rizu.api.Task]]
		live[task] = true
	end
	local index = 0
	for _, child in ipairs(self.children) do
		local item = child --[[@as ui.modals.notifications.NotificationItem]]
		local task = item.task
		if task then
			shown[task] = true
			if not live[task] then item:leave(noop) end
			index = index + 1
		end
	end
	for i = 1, api:getTaskCount() do
		local task = api:getTask(i) --[[@as rizu.api.Task]]
		if not shown[task] then
			index = index + 1
			self:insert(index, self:createItem(nil, task))
		end
	end
end

---@param dt number
function NotificationToasts:update(dt)
	if not self.is_allowed() then
		if #self.children > 0 then self:clearAll() end
		return
	end
	self:syncTasks()
	for item, time in pairs(self.toasts) do
		-- A hovered toast stays so its actions can be clicked.
		if not item.mouse_over then
			time = time - dt
			self.toasts[item] = time
			if time <= 0 then self:hideItem(item) end
		end
	end
	local _, height = self:getContentSize()
	self:setHeight(height)
end

return NotificationToasts
