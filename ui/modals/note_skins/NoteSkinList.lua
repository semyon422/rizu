local Colors = require("ui.Colors")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local VirtualizedList = require("gui.VirtualizedList")

---@class ui.modals.note_skins.NoteSkinList : gui.VirtualizedList
---@operator call: ui.modals.note_skins.NoteSkinList
local NoteSkinList = VirtualizedList + {}

local ITEM_HEIGHT = 62
local GAP = 7
local RADIO_X = 20
local TEXT_X = 58

---@param on_select fun(index: integer)
function NoteSkinList:new(on_select)
	VirtualizedList.new(self)
	self.item_height = ITEM_HEIGHT
	self.gap = GAP
	self.items = {}
	self.selected_path = nil
	self.hover_index = nil
	self.on_select = on_select
	self.font = Resources.getFont("medium", 21)
	self.background = NineSliceUsage(Resources.nine_slices.note_skin_item)
	self.hover_background = NineSliceUsage(Resources.nine_slices.note_skin_item_hover)
	self.selected_background = NineSliceUsage(Resources.nine_slices.note_skin_item_selected)
end

---@return integer
function NoteSkinList:getItemCount()
	return #self.items
end

---@param items sphere.SkinInfo[]
---@param selected_path string?
function NoteSkinList:setItems(items, selected_path)
	self.items = items
	self.selected_path = selected_path
	self:scrollTo(0, true)
end

---@param screen_x number
---@param screen_y number
---@return integer?
function NoteSkinList:getIndexAt(screen_x, screen_y)
	local local_y = self:getLocalY(screen_x, screen_y)
	if local_y < 0 or local_y >= self.height then return end
	local index = math.floor((local_y + self:getVisualScrollPosition()) / self:getRowStep()) + 1
	if self.items[index] then return index end
end

function NoteSkinList:update(dt)
	VirtualizedList.update(self, dt)
	self.hover_index = self.mouse_over and self:getIndexAt(love.mouse.getPosition()) or nil
end

---@param e gui.MouseClickEvent
---@return boolean?
function NoteSkinList:onMouseClick(e)
	if e.button ~= 1 or self.drag_active then return end
	local index = self:getIndexAt(e.x, e.y)
	if not index then return end
	self.on_select(index)
	return true
end

function NoteSkinList:draw()
	if #self.items == 0 then
		Painter.setColorTable(Colors.muted)
		love.graphics.setFont(self.font)
		love.graphics.printf("No compatible note skins", 0, 60, self.width, "center")
		return
	end

	local scroll = math.floor(self:getVisualScrollPosition() + 0.5)
	local first_index, last_index = self:getVisibleRowRange()
	for index = first_index, last_index do
		local item = self.items[index]
		local selected = item:getPath() == self.selected_path
		local y = math.floor((index - 1) * self:getRowStep() - scroll + 0.5)

		Painter.setColorRgb(1, 1, 1)
		local background = selected and self.selected_background
			or (index == self.hover_index and self.hover_background or self.background)
		love.graphics.push()
		love.graphics.translate(0, y)
		background:draw(self.width, ITEM_HEIGHT)
		love.graphics.pop()
		Painter.setColorTable(Colors.text)
		local radio = Resources.sprites.radio_body
		local radio_y = math.floor(y + (ITEM_HEIGHT - radio:getHeight()) / 2 + 0.5)
		radio:draw(RADIO_X, radio_y)
		if selected then
			Painter.setColorRgb(1, 1, 1)
			local mark = Resources.sprites.radio_mark
			local mark_x = math.floor(RADIO_X + (radio:getWidth() - mark:getWidth()) / 2 + 0.5)
			local mark_y = math.floor(y + (ITEM_HEIGHT - mark:getHeight()) / 2 + 0.5)
			mark:draw(mark_x, mark_y)
		end

		Painter.setColorTable(Colors.text)
		love.graphics.setFont(self.font)
		love.graphics.print(item.name, TEXT_X, y + (ITEM_HEIGHT - self.font:getHeight()) / 2)
	end
end

return NoteSkinList
