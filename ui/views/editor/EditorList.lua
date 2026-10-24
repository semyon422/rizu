local Colors = require("ui.Colors")
local EditorRow = require("ui.views.editor.EditorRow")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local VirtualizedList = require("gui.VirtualizedList")

---@class ui.views.editor.EditorList.Item
---@field name string Shown in the row.
---@field id string Identifies the item; the selected item has `selected_id`.

---Flat rows to pick one item from. The selected row is raised and marked with an accent bar.
---@class ui.views.editor.EditorList : gui.VirtualizedList
---@operator call: ui.views.editor.EditorList
---@field items ui.views.editor.EditorList.Item[]
---@field selected_id string?
---@field hover_index integer?
---@field on_select fun(index: integer)
---@field font love.Font
local EditorList = VirtualizedList + {}

local MARK_WIDTH = 2
local TEXT_X = 12

---@param on_select fun(index: integer)
function EditorList:new(on_select)
	VirtualizedList.new(self)
	self.item_height = EditorRow.HEIGHT
	self.gap = 0
	self.items = {}
	self.selected_id = nil
	self.hover_index = nil
	self.on_select = on_select
	self.font = Resources.getFont("regular", 16)
end

---@return integer
function EditorList:getItemCount()
	return #self.items
end

---@param items ui.views.editor.EditorList.Item[]
---@param selected_id string?
function EditorList:setItems(items, selected_id)
	local same = #items == #self.items
	for i = 1, same and #items or 0 do
		if items[i].id ~= self.items[i].id or items[i].name ~= self.items[i].name then same = false break end
	end
	self.items = items
	self.selected_id = selected_id
	-- Picking an item refreshes the list with the same items: keep the scroll position.
	if not same then self:scrollTo(0, true) end
end

---@param screen_x number
---@param screen_y number
---@return integer?
function EditorList:getIndexAt(screen_x, screen_y)
	local local_y = self:getLocalY(screen_x, screen_y)
	if local_y < 0 or local_y >= self.height then return end
	local index = math.floor((local_y + self:getVisualScrollPosition()) / self:getRowStep()) + 1
	if self.items[index] then return index end
end

function EditorList:update(dt)
	VirtualizedList.update(self, dt)
	self.hover_index = self.mouse_over and self:getIndexAt(love.mouse.getPosition()) or nil
end

---@param e gui.MouseClickEvent
---@return boolean?
function EditorList:onMouseClick(e)
	if e.button ~= 1 or self.drag_active then return end
	local index = self:getIndexAt(e.x, e.y)
	if not index then return end
	self.on_select(index)
	return true
end

function EditorList:draw()
	local height = self.item_height
	local scroll = math.floor(self:getVisualScrollPosition() + 0.5)
	local first_index, last_index = self:getVisibleRowRange()
	love.graphics.setFont(self.font)
	local text_y = math.floor((height - self.font:getHeight()) / 2)
	for index = first_index, last_index do
		local item = self.items[index]
		local selected = item.id == self.selected_id
		local y = (index - 1) * self:getRowStep() - scroll
		if selected then
			EditorRow.fillRect(Colors.surface_raised, 0, y, self.width, height)
			EditorRow.fillRect(Colors.accent, 0, y, MARK_WIDTH, height)
		elseif index == self.hover_index then
			EditorRow.fillRect(Colors.surface, 0, y, self.width, height)
		end
		Painter.setColorTable((selected or index == self.hover_index) and Colors.text or Colors.muted)
		love.graphics.print(item.name, TEXT_X, y + text_y)
	end
end

return EditorList
