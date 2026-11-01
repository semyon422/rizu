local View = require("gui.View")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local NineSliceUsage = require("gui.NineSliceUsage")
local Resources = require("ui.Resources")

---A notification or a running task card.
---@class ui.modals.notifications.NotificationItem : gui.View
---@operator call: ui.modals.notifications.NotificationItem
---@field notification rizu.api.Notification?
---@field task rizu.api.Task?
---@field localization ui.localization.Localization
---@field on_dismiss fun(item: ui.modals.notifications.NotificationItem)?
---@field on_action fun(item: ui.modals.notifications.NotificationItem, index: integer)?
---@field on_click fun(item: ui.modals.notifications.NotificationItem)? A click outside the close button and actions.
---@field on_right_click fun(item: ui.modals.notifications.NotificationItem)?
---@field color gui.Color
---@field icon gui.Sprite
---@field title string
---@field title_lines string[]
---@field text_lines string[]
---@field action_labels string[]
---@field action_widths number[]
---@field actions_y number?
---@field progress_y number
---@field time_y number?
---@field leaving boolean
local NotificationItem = View + {}

local PADDING = 14
local STRIPE = 3
local ICON_SIZE = 32
local ICON_GLYPH = 18
local TEXT_X = STRIPE + PADDING + ICON_SIZE + 12
local CLOSE_SIZE = 24
local CLOSE_INSET = 10
local PROGRESS_HEIGHT = 5
local INDETERMINATE_WIDTH = 0.3
local INDETERMINATE_PERIOD = 1.4
local SPIN_PERIOD = 1.2
local ACTION_GAP = 16

local kind_colors = {
	info = Colors.cyan,
	success = Colors.success,
	error = Colors.danger,
	server = Colors.magenta,
}

local type_icons = {
	screenshot_saved = "icon_camera",
}

local kind_icons = {
	info = "icon_info",
	success = "icon_check",
	error = "icon_alert",
	server = "icon_server",
}

---@param n integer
---@return string
local function groupThousands(n)
	return (tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

---Translates by type, falling back to the game's English.
---@param localization ui.localization.Localization
---@param key string
---@param params table
---@param fallback string?
---@return string?
local function translate(localization, key, params, fallback)
	local text = localization:get(key, params)
	if text == key then return fallback end
	return text
end

---@param seconds number
---@param localization ui.localization.Localization
---@return string
local function formatAge(seconds, localization)
	if seconds < 60 then
		return localization:get("notifications.just_now")
	elseif seconds < 3600 then
		return localization:get("notifications.minutes_ago", {count = math.floor(seconds / 60)})
	end
	return localization:get("notifications.hours_ago", {count = math.floor(seconds / 3600)})
end

---@param width number
---@param localization ui.localization.Localization
---@param notification rizu.api.Notification?
---@param task rizu.api.Task?
---@param on_dismiss fun(item: ui.modals.notifications.NotificationItem)?
---@param on_action fun(item: ui.modals.notifications.NotificationItem, index: integer)?
function NotificationItem:new(width, localization, notification, task, on_dismiss, on_action)
	View.new(self)
	assert((notification == nil) ~= (task == nil), "an item shows a notification or a task")
	self.notification = notification
	self.task = task
	self.localization = localization
	self.on_dismiss = on_dismiss
	self.on_action = on_action
	self.handles_mouse_input = true
	self.leaving = false
	local kind = notification and notification.kind
	self.color = task and Colors.accent or kind_colors[kind] or Colors.cyan
	local type_icon = notification and type_icons[notification.type]
	self.icon = Resources.sprites[task and "icon_spinner" or type_icon or kind_icons[kind] or "icon_info"]

	local sprites = Resources.nine_slices
	self.background = NineSliceUsage(sprites.notification_item)
	self.stripe = NineSliceUsage(sprites.notification_item_stripe)
	self.title_font = Resources.getFont("medium", 18)
	self.text_font = Resources.getFont("regular", 16)
	self.small_font = Resources.getFont("regular", 14)

	local entry = notification or task --[[@as rizu.api.Notification]]
	local key = "notifications.type." .. entry.type
	self.title = translate(localization, key, entry.params, entry.title) --[[@as string]]
	local text = translate(localization, key .. ".text", entry.params, entry.text)
	-- The title stops short of the close button, which shows on hover.
	local _, title_lines = self.title_font:getWrap(self.title, width - TEXT_X - CLOSE_SIZE - CLOSE_INSET)
	self.title_lines = title_lines
	self.text_lines = {}
	if text then
		local _, lines = self.text_font:getWrap(text, width - TEXT_X - PADDING)
		self.text_lines = lines
	end
	self.action_labels, self.action_widths = {}, {}
	for i, action in ipairs(notification and notification.actions or {}) do
		self.action_labels[i] = translate(localization, "notifications.action." .. action.id, {}, action.label)
		self.action_widths[i] = self.text_font:getWidth(self.action_labels[i])
	end
	self:setWidth(width)
	self:layout()
end

---Places the rows. A task gets its count row once its size is known.
function NotificationItem:layout()
	local y = PADDING + #self.title_lines * self.title_font:getHeight()
	if #self.text_lines > 0 then
		y = y + 2 + #self.text_lines * self.text_font:getHeight()
	end
	self.actions_y = nil
	self.time_y = nil
	if self.notification then
		if #self.action_labels > 0 then
			self.actions_y = y + 4
			y = self.actions_y + self.text_font:getHeight()
		end
		self.time_y = y + 6
		y = self.time_y + self.small_font:getHeight()
	else
		self.progress_y = y + 10
		y = self.progress_y + PROGRESS_HEIGHT
		if self.task.total then
			self.time_y = y + 6
			y = self.time_y + self.small_font:getHeight()
		end
	end
	self:setHeight(math.max(y + PADDING, PADDING * 2 + ICON_SIZE))
end

function NotificationItem:update()
	local task = self.task
	if task and (task.total ~= nil) ~= (self.time_y ~= nil) then
		self:layout()
	end
end

---@return number x
---@return number y
function NotificationItem:getCloseRect()
	return self.width - CLOSE_INSET - CLOSE_SIZE, CLOSE_INSET
end

---@param x number Local.
---@param y number Local.
---@return boolean
function NotificationItem:isOverClose(x, y)
	if not self.notification then return false end
	local cx, cy = self:getCloseRect()
	return x >= cx and x <= cx + CLOSE_SIZE and y >= cy and y <= cy + CLOSE_SIZE
end

---@param x number Local.
---@param y number Local.
---@return integer? index
function NotificationItem:getActionAt(x, y)
	local actions_y = self.actions_y
	if not actions_y or y < actions_y or y > actions_y + self.text_font:getHeight() then return end
	local left = TEXT_X
	for i, w in ipairs(self.action_widths) do
		if x >= left and x <= left + w then return i end
		left = left + w + ACTION_GAP
	end
end

---@return number? x
---@return number? y
function NotificationItem:getLocalMouse()
	local inputs = self.screen and self.screen.inputs
	if not self.mouse_over or not inputs then return end
	return self.world_transform:inverseTransformPoint(inputs.mouse_x, inputs.mouse_y)
end

---Slides the item out, then removes it.
---@param on_removed fun()
---@param delay number?
function NotificationItem:leave(on_removed, delay)
	if self.leaving then return end
	self.leaving = true
	self.handles_mouse_input = false
	local chain = self:delay(delay or 0)
	chain:fadeOut(0.25, "OutCubic")
	chain:transformTo("offset_x", 60, 0.25, "OutCubic", function()
		self.parent:remove(self)
		on_removed()
	end)
end

---@param e gui.MouseClickEvent
---@return boolean? handled
function NotificationItem:onMouseClick(e)
	if e.button == 2 and self.on_right_click then
		self.on_right_click(self)
		return true
	end
	if e.button ~= 1 then return end
	local x, y = self.world_transform:inverseTransformPoint(e.x, e.y)
	local action = self:getActionAt(x, y)
	if self:isOverClose(x, y) and self.on_dismiss then
		self.on_dismiss(self)
	elseif action and self.on_action then
		self.on_action(self, action)
	elseif self.on_click then
		self.on_click(self)
	end
	return true
end

function NotificationItem:draw()
	local mx, my = self:getLocalMouse()
	local width, height = self.width, self.height
	Painter.setColorTable(self.mouse_over and Colors.surface_raised or Colors.surface)
	self.background:draw(width, height)
	Painter.setColorTable(self.color)
	self.stripe:draw(width, height)

	local color = self.color
	local icon_x, icon_y = STRIPE + PADDING, PADDING
	Painter.setColorRgb(color[1], color[2], color[3], 0.18)
	local circle = Resources.sprites.notification_icon
	circle:draw(icon_x, icon_y, 0, ICON_SIZE / circle:getWidth(), ICON_SIZE / circle:getHeight())
	Painter.setColorTable(color)
	local icon = self.icon
	local scale = ICON_GLYPH / icon:getWidth()
	local rotation = self.task and love.timer.getTime() % SPIN_PERIOD / SPIN_PERIOD * math.pi * 2 or 0
	icon:draw(icon_x + ICON_SIZE / 2, icon_y + ICON_SIZE / 2, rotation, scale, scale,
		icon:getWidth() / 2, icon:getHeight() / 2)

	Painter.snapToPixel()
	Painter.setColorTable(Colors.text)
	love.graphics.setFont(self.title_font)
	local line_y = PADDING
	for _, line in ipairs(self.title_lines) do
		love.graphics.print(line, TEXT_X, line_y)
		line_y = line_y + self.title_font:getHeight()
	end
	local notification = self.notification

	Painter.setColorTable(Colors.muted)
	love.graphics.setFont(self.text_font)
	line_y = line_y + 2
	for _, line in ipairs(self.text_lines) do
		love.graphics.print(line, TEXT_X, line_y)
		line_y = line_y + self.text_font:getHeight()
	end

	if notification then
		local actions_y = self.actions_y
		if actions_y then
			local hovered = mx and my and self:getActionAt(mx, my)
			local underline_y = actions_y + self.text_font:getBaseline() + 2
			local left = TEXT_X
			Painter.setColorTable(color)
			for i, label in ipairs(self.action_labels) do
				love.graphics.print(label, left, actions_y)
				if i == hovered then
					Resources.sprites.pixel:draw(left, underline_y, 0, self.action_widths[i], 1)
				end
				left = left + self.action_widths[i] + ACTION_GAP
			end
		end
		Painter.setColorTable(Colors.muted)
		love.graphics.setFont(self.small_font)
		local meta = formatAge(os.time() - notification.time, self.localization)
		if notification.count > 1 then meta = meta .. " · ×" .. notification.count end
		love.graphics.print(meta, TEXT_X, self.time_y)
		if self.mouse_over then
			local cx, cy = self:getCloseRect()
			if mx and my and self:isOverClose(mx, my) then
				Painter.setColorTable(Colors.outline)
				Resources.sprites.pixel:draw(cx, cy, 0, CLOSE_SIZE, CLOSE_SIZE)
				Painter.setColorTable(Colors.text)
			end
			local close = Resources.sprites.icon_x
			local close_scale = 14 / close:getWidth()
			close:draw(cx + (CLOSE_SIZE - 14) / 2, cy + (CLOSE_SIZE - 14) / 2, 0, close_scale, close_scale)
		end
		return
	end

	local task = self.task --[[@as rizu.api.Task]]
	local bar_width = width - TEXT_X - PADDING
	Painter.setColorTable(Colors.background)
	Resources.sprites.pixel:draw(TEXT_X, self.progress_y, 0, bar_width, PROGRESS_HEIGHT)
	Painter.setColorTable(Colors.accent)
	local from, to ---@type number, number
	if task.total then
		from, to = 0, (task.done or 0) / task.total
	else
		local t = love.timer.getTime() % INDETERMINATE_PERIOD / INDETERMINATE_PERIOD
		local eased = t < 0.5 and 2 * t * t or 1 - (-2 * t + 2) ^ 2 / 2
		from = -INDETERMINATE_WIDTH + eased * (1 + INDETERMINATE_WIDTH * 2)
		to = from + INDETERMINATE_WIDTH
	end
	from, to = math.max(from, 0), math.min(to, 1)
	if to > from then
		Resources.sprites.pixel:draw(TEXT_X + from * bar_width, self.progress_y, 0,
			(to - from) * bar_width, PROGRESS_HEIGHT)
	end

	if task.total and self.time_y then
		local done = task.done or 0
		Painter.setColorTable(Colors.muted)
		love.graphics.setFont(self.small_font)
		love.graphics.print(groupThousands(done) .. " / " .. groupThousands(task.total), TEXT_X, self.time_y)
		local percent = math.floor(done / task.total * 100) .. "%"
		love.graphics.printf(percent, TEXT_X, self.time_y, bar_width, "right")
	end
end

return NotificationItem
