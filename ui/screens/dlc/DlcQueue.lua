local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local VirtualizedList = require("gui.VirtualizedList")

---@class ui.screens.dlc.DlcQueue : gui.VirtualizedList
---@operator call: ui.screens.dlc.DlcQueue
local DlcQueue = VirtualizedList + {}

local ITEM_HEIGHT = 82
local PADDING = 12

function DlcQueue:new()
	VirtualizedList.new(self)
	self.item_height = ITEM_HEIGHT
	self.gap = 6
	self.tasks = {}
	self.title_font = Resources.getFont("cjk_bold", 16)
	self.detail_font = Resources.getFont("regular", 14)
end

function DlcQueue:getItemCount()
	return #self.tasks
end

---@param tasks rizu.dlc.DlcTask[]
function DlcQueue:setTasks(tasks)
	self.tasks = tasks
	self.scroll_target = self:clampScroll(self.scroll_target)
end

local function formatSpeed(speed)
	if speed >= 1024 * 1024 then return ("%.1f MiB/s"):format(speed / 1024 / 1024) end
	return ("%.0f KiB/s"):format(speed / 1024)
end

function DlcQueue:draw()
	local scroll = self:getVisualScrollPosition()
	local first_index, last_index = self:getVisibleRowRange()
	for index = first_index, last_index do
		local task = self.tasks[index]
		local y = (index - 1) * self:getRowStep() - scroll
		Painter.setColorTable(index % 2 == 0 and Colors.surface or Colors.panel)
		Resources.sprites.pixel:draw(0, y, 0, self.width, self.item_height)

		local title = task.metadata and (task.metadata.title or task.metadata.name) or tostring(task.id)
		Painter.setColorTable(Colors.text)
		love.graphics.setFont(self.title_font)
		love.graphics.printf(title, PADDING, y + 10, self.width - PADDING * 2, "left")

		local progress = math.max(0, math.min(1, task.progress or 0))
		Painter.setColorTable(Colors.background)
		Resources.sprites.pixel:draw(PADDING, y + 42, 0, self.width - PADDING * 2, 7)
		Painter.setColorTable(task.status == "error" and Colors.danger or Colors.accent)
		Resources.sprites.pixel:draw(PADDING, y + 42, 0, (self.width - PADDING * 2) * progress, 7)

		Painter.setColorTable(task.status == "error" and Colors.danger or Colors.muted)
		love.graphics.setFont(self.detail_font)
		local detail = task.error or task.status
		if task.status == "downloading" then detail = detail .. "  " .. formatSpeed(task.speed or 0) end
		love.graphics.printf(detail, PADDING, y + 56, self.width - PADDING * 2, "left")
	end
end

return DlcQueue
