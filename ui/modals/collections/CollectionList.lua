local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local VirtualizedList = require("gui.VirtualizedList")

---@class ui.modals.collections.CollectionList : gui.VirtualizedList
---@operator call: ui.modals.collections.CollectionList
---@field options ui.screens.song_select.DropdownOption[]
---@field selected_index integer
---@field hover_index integer?
local CollectionList = VirtualizedList + {}

local ITEM_HEIGHT = 54
local TEXT_X = 16

---@param on_select fun(index: integer)
---@param on_confirm fun(index: integer)
function CollectionList:new(on_select, on_confirm)
	VirtualizedList.new(self)
	self.item_height = ITEM_HEIGHT
	self.options = {}
	self.selected_index = 1
	self.hover_index = nil
	self.on_select = on_select
	self.on_confirm = on_confirm
	self.title_font = Resources.getFont("medium", 17)
	self.detail_font = Resources.getFont("regular", 13)
end

---@return integer count
function CollectionList:getItemCount()
	return #self.options
end

---@param options ui.screens.song_select.DropdownOption[]
function CollectionList:setOptions(options)
	self.options = options
	self.selected_index = math.max(1, math.min(self.selected_index, math.max(1, #options)))
	self:scrollTo(self.scroll_target)
end

---@param index integer
---@param immediate boolean?
function CollectionList:setSelectedIndex(index, immediate)
	if #self.options == 0 then
		self.selected_index = 1
		return
	end
	self.selected_index = math.max(1, math.min(index, #self.options))
	local top = (self.selected_index - 1) * self:getRowStep()
	local bottom = top + self.item_height
	if top < self.scroll_target or bottom > self.scroll_target + self.height then
		self:scrollTo(top + self.item_height / 2 - self.height / 2, immediate)
	end
end

---@param screen_x number
---@param screen_y number
---@return integer? index
function CollectionList:getIndexAt(screen_x, screen_y)
	local local_y = self:getLocalY(screen_x, screen_y)
	if local_y < 0 or local_y >= self.height then return end
	local index = math.floor((local_y + self:getVisualScrollPosition()) / self:getRowStep()) + 1
	if self.options[index] then return index end
end

---@param dt number
function CollectionList:update(dt)
	VirtualizedList.update(self, dt)
	self.hover_index = self.mouse_over and self:getIndexAt(love.mouse.getPosition()) or nil
end

---@param e gui.MouseClickEvent
---@return boolean?
function CollectionList:onMouseClick(e)
	if e.button ~= 1 or self.drag_active then return end
	local index = self:getIndexAt(e.x, e.y)
	if not index then return end
	self.on_select(index)
	self.on_confirm(index)
	return true
end

function CollectionList:draw()
	if #self.options == 0 then
		Painter.setColorTable(Colors.muted)
		love.graphics.setFont(self.title_font)
		love.graphics.printf("No matching collections or locations", 0, 24, self.width, "center")
		return
	end
	local scroll = self:getVisualScrollPosition()
	local first_index, last_index = self:getVisibleRowRange()
	for index = first_index, last_index do
		local option = self.options[index]
		local node = option.value --[[@as rizu.library.Collections.TreeNode]]
		local y = (index - 1) * self:getRowStep() - scroll
		if index == self.selected_index then
			Painter.setColorTable(Colors.surface_raised)
			Resources.sprites.pixel:draw(0, y, 0, self.width, self.item_height)
		elseif index == self.hover_index then
			Painter.setColorTable(Colors.surface)
			Resources.sprites.pixel:draw(0, y, 0, self.width, self.item_height)
		end

		Painter.setColorTable(Colors.text)
		love.graphics.setFont(self.title_font)
		love.graphics.print(option.label, TEXT_X, y + 7)
		Painter.setColorTable(Colors.muted)
		love.graphics.setFont(self.detail_font)
		local kind = node.depth == 0 and "Library" or (node.path == nil and "Location" or "Collection")
		love.graphics.print(("%s - %d charts"):format(kind, node.count), TEXT_X, y + 32)
	end
end

return CollectionList
