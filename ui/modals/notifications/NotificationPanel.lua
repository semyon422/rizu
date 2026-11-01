local View = require("gui.View")
local FlowContainer = require("gui.layout.FlowContainer")
local TrackContainer = require("gui.layout.TrackContainer")
local ScrollView = require("gui.ScrollView")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Colors = require("ui.Colors")
local Resources = require("ui.Resources")
local Label = require("ui.views.Label")
local Panel = require("ui.views.Panel")
local ModalView = require("ui.ModalView")
local NotificationItem = require("ui.modals.notifications.NotificationItem")

---Text with an optional trailing icon. As a bar it gets the close bar background.
---@class ui.modals.notifications.NotificationPanel.TextButton : gui.View
---@operator call: ui.modals.notifications.NotificationPanel.TextButton
---@field text string
---@field font love.Font
---@field icon gui.Sprite?
---@field on_click fun()
---@field background gui.NineSliceUsage?
---@field hover_background gui.NineSliceUsage?
local TextButton = View + {}

local TEXT_BUTTON_ICON = 18

---@param text string
---@param font love.Font
---@param on_click fun()
---@param bar boolean
function TextButton:new(text, font, on_click, bar)
	View.new(self)
	self.text = text
	self.font = font
	self.on_click = on_click
	self.handles_mouse_input = true
	if bar then
		self.icon = Resources.sprites.icon_chevron_right
		self.background = NineSliceUsage(Resources.nine_slices.notification_close_bar)
		self.hover_background = NineSliceUsage(Resources.nine_slices.notification_close_bar_hover)
	end
	self:setSize(font:getWidth(text), font:getHeight())
end

---@param e gui.MouseClickEvent
---@return boolean? handled
function TextButton:onMouseClick(e)
	if e.button ~= 1 then return end
	self.on_click()
	return true
end

function TextButton:draw()
	local width, height = self.width, self.height
	local background = self.mouse_over and self.hover_background or self.background
	if background then
		Painter.setColorRgb(1, 1, 1)
		background:draw(width, height)
	end
	Painter.snapToPixel()
	Painter.setColorTable(self.mouse_over and Colors.text or Colors.muted)
	love.graphics.setFont(self.font)
	local text_width = self.font:getWidth(self.text)
	local icon = self.icon
	local content_width = text_width + (icon and 8 + TEXT_BUTTON_ICON or 0)
	local x = math.floor((width - content_width) / 2)
	love.graphics.print(self.text, x, math.floor((height - self.font:getHeight()) / 2))
	if icon then
		local scale = TEXT_BUTTON_ICON / icon:getHeight()
		icon:draw(x + text_width + 8, (height - TEXT_BUTTON_ICON) / 2, 0, scale, scale)
	end
end

---Slides in from the right edge with the running tasks and the notifications.
---@class ui.modals.notifications.NotificationPanel : ui.ModalView
---@operator call: ui.modals.notifications.NotificationPanel
---@field api rizu.api.Notifications
---@field localization ui.localization.Localization
---@field layout gui.layout.TrackContainer
---@field tasks gui.layout.FlowContainer Section head, task items, empty text.
---@field tasks_empty ui.views.Label
---@field list gui.layout.FlowContainer Notification items, empty text.
---@field list_empty ui.views.Label
---@field scroll gui.ScrollView
local NotificationPanel = ModalView + {}

local WIDTH = 460
local PADDING_X = 14
local ITEM_WIDTH = WIDTH - PADDING_X * 2
local SECTION_HEAD_HEIGHT = 32
local EMPTY_HEIGHT = 64
local GAP = 10
local HIDDEN_OFFSET = WIDTH + 40
local GLIDE = {duration = 0.25, easing = "OutCubic"}

local function noop() end

---@param api rizu.api.Notifications
---@param localization ui.localization.Localization
---@param on_close fun()
function NotificationPanel:new(api, localization, on_close)
	ModalView.new(self)
	self.api = api
	self.localization = localization
	self:fillHeight(0, 0):setWidth(WIDTH):setAlignmentX(1)
	self:setOffset(HIDDEN_OFFSET, 0):setVisible(false)
	self.handles_mouse_input = true

	self:add(Panel({color = Colors.panel, line_color = Colors.outline, lines = {left = true}}))
		:anchorFill(0, 0, 0, 0)

	local layout = self:add(TrackContainer({
		direction = "column",
		gap = 18,
		padding = {PADDING_X, 18, PADDING_X, 14},
		layout_transition = GLIDE,
	}))
	layout:anchorFill(0, 0, 0, 0)
	self.layout = layout
	layout:add(TextButton(localization:get("notifications.close"), Resources.getFont("regular", 18), on_close, true),
		52)

	self.tasks = layout:add(FlowContainer({direction = "column", gap = GAP, layout_transition = GLIDE}), 0)
	self.tasks:add(self:createSectionHead("notifications.tasks"))
	self.tasks_empty = self:createEmpty("notifications.no_tasks")

	local notifications = layout:add(TrackContainer({direction = "column"}), "*")
	local head = notifications:add(self:createSectionHead("notifications.notifications"), SECTION_HEAD_HEIGHT + GAP)
	local clear = head:add(TextButton(localization:get("notifications.clear_all"), Resources.getFont("medium", 15),
		function() self:clearAll() end, false))
	clear:setAlignment(1, 0):addPosition(-4, 0)
	self.list = FlowContainer({direction = "column", gap = GAP, layout_transition = GLIDE})
	self.list_empty = self:createEmpty("notifications.empty")
	self.scroll = notifications:add(ScrollView(self.list), "*")
end

---@private
---@param key string
---@return gui.View
function NotificationPanel:createSectionHead(key)
	local head = View()
	head:setSize(ITEM_WIDTH, SECTION_HEAD_HEIGHT)
	local label = head:add(Label({
		font_name = "medium",
		font_size = 15,
		color = Colors.muted,
		text = self.localization:get(key):upper(),
	}))
	label:setPosition(4, 0)
	return head
end

---@private
---@param key string
---@return ui.views.Label
function NotificationPanel:createEmpty(key)
	local label = Label({
		font_name = "regular",
		font_size = 18,
		color = Colors.muted,
		align = "center",
		text = self.localization:get(key),
	})
	label:setSize(ITEM_WIDTH, EMPTY_HEIGHT)
	return label
end

---@private
---@param notification rizu.api.Notification?
---@param task rizu.api.Task?
---@return ui.modals.notifications.NotificationItem
function NotificationPanel:createItem(notification, task)
	return NotificationItem(ITEM_WIDTH, self.localization, notification, task,
		function(item) self:dismiss(item) end,
		function(item, index) self.api:runAction(item.notification.id, index) end)
end

---@param container gui.View
---@return ui.modals.notifications.NotificationItem[]
local function getItems(container)
	local items = {} ---@type ui.modals.notifications.NotificationItem[]
	for _, child in ipairs(container.children) do
		if NotificationItem * child then
			items[#items + 1] = child --[[@as ui.modals.notifications.NotificationItem]]
		end
	end
	return items
end

---Shows the empty text while a section has no items, leaving ones included.
---@param container gui.View
---@param empty gui.View
local function updateEmpty(container, empty)
	local show = #getItems(container) == 0
	if show and empty.parent ~= container then
		container:add(empty)
	elseif not show and empty.parent == container then
		container:remove(empty)
	end
end

---@param item ui.modals.notifications.NotificationItem
---@param animate boolean
local function enter(item, animate)
	if not animate then return end
	item:setOffset(40, 0):setOpacity(0)
	item:moveTo(0, 0, 0.3, "OutQuint")
	item:fadeIn(0.3, "OutCubic")
end

---@private
---Adds items for new tasks and notifications and slides out the ones that are gone.
---@param animate boolean
function NotificationPanel:sync(animate)
	local api = self.api
	local live, shown = {}, {} ---@type {[table]: true}, {[table]: true}
	for i = 1, api:getTaskCount() do
		local task = api:getTask(i) --[[@as rizu.api.Task]]
		live[task] = true
	end
	for _, item in ipairs(getItems(self.tasks)) do
		local task = item.task --[[@as rizu.api.Task]]
		shown[task] = true
		if not live[item.task] then item:leave(noop) end
	end
	for i = 1, api:getTaskCount() do
		local task = api:getTask(i) --[[@as rizu.api.Task]]
		if not shown[task] then enter(self.tasks:add(self:createItem(nil, task)), animate) end
	end

	live, shown = {}, {}
	for i = 1, api:getCount() do
		local notification = api:getNotification(i) --[[@as rizu.api.Notification]]
		live[notification] = true
	end
	for _, item in ipairs(getItems(self.list)) do
		local notification = item.notification --[[@as rizu.api.Notification]]
		shown[notification] = true
		if not live[item.notification] then item:leave(noop) end
	end
	-- Inserting from the oldest keeps the newest on top.
	for i = api:getCount(), 1, -1 do
		local notification = api:getNotification(i) --[[@as rizu.api.Notification]]
		if not shown[notification] then enter(self.list:insert(1, self:createItem(notification)), animate) end
	end

	self:sortList()
	updateEmpty(self.tasks, self.tasks_empty)
	updateEmpty(self.list, self.list_empty)
	self.tasks:fitContent()
	self.layout:setTrackSize(self.tasks, self.tasks:getAuthoredHeight())
	self.list:fitContent()
end

---@private
---Moves a notification posted again to the top, as the list has it. Leaving items end up below.
function NotificationPanel:sortList()
	local api = self.api
	local staying = {} ---@type ui.modals.notifications.NotificationItem[]
	for _, item in ipairs(getItems(self.list)) do
		if not item.leaving then staying[#staying + 1] = item end
	end
	local sorted = true
	for i, item in ipairs(staying) do
		if api:getNotification(i) ~= item.notification or self.list.children[i] ~= item then
			sorted = false
			break
		end
	end
	if sorted then return end
	local by_notification = {} ---@type {[rizu.api.Notification]: ui.modals.notifications.NotificationItem}
	for _, item in ipairs(staying) do
		local notification = item.notification --[[@as rizu.api.Notification]]
		by_notification[notification] = item
	end
	local index = 1
	for i = 1, api:getCount() do
		local notification = api:getNotification(i) --[[@as rizu.api.Notification]]
		local item = by_notification[notification]
		if item then
			self.list:move(item, index)
			index = index + 1
		end
	end
end

---@private
---@param item ui.modals.notifications.NotificationItem
---@param delay number?
function NotificationPanel:dismiss(item, delay)
	item:leave(noop, delay)
	self.api:dismiss(item.notification.id)
end

---@private
function NotificationPanel:clearAll()
	local delay = 0
	for _, item in ipairs(getItems(self.list)) do
		if not item.leaving then
			item:leave(noop, delay)
			delay = delay + 0.05
		end
	end
	self.api:clear()
end

function NotificationPanel:update()
	if self.api:getUnreadCount() > 0 then
		self.api:markRead()
	end
	self:sync(true)
end

function NotificationPanel:show()
	for _, item in ipairs(getItems(self.tasks)) do self.tasks:remove(item) end
	self.list:clear()
	self:sync(false)
	self.api:markRead()
	self:setVisible(true)
	self:moveToX(0, 0.35, "OutQuint")
end

function NotificationPanel:hide()
	self:transformTo("offset_x", HIDDEN_OFFSET, 0.25, "InCubic", function()
		self:setVisible(false)
	end)
end

return NotificationPanel
