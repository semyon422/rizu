local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local VirtualizedList = require("gui.VirtualizedList")

---@class ui.screens.remote_catalog.RemoteCatalogList : gui.VirtualizedList
---@operator call: ui.screens.remote_catalog.RemoteCatalogList
---@field items rizu.library.RemoteCatalogItem[]
---@field selected_index integer?
---@field hover_index integer?
---@field on_select fun(item: rizu.library.RemoteCatalogItem, index: integer)?
local RemoteCatalogList = VirtualizedList + {}

local ITEM_HEIGHT = 70
local PADDING = 16

---@param on_select fun(item: rizu.library.RemoteCatalogItem, index: integer)?
function RemoteCatalogList:new(on_select)
	VirtualizedList.new(self)
	self.item_height = ITEM_HEIGHT
	self.gap = 4
	self.items = {}
	self.on_select = on_select
	self.selected_index = nil
	self.hover_index = nil
	self.title_font = Resources.getFont("cjk_bold", 20)
	self.detail_font = Resources.getFont("cjk_regular", 15)
end

---@return integer
function RemoteCatalogList:getItemCount()
	return #self.items
end

---@param items rizu.library.RemoteCatalogItem[]
function RemoteCatalogList:setItems(items)
	self.items = items
	self.selected_index = nil
	self.hover_index = nil
	self:stopScrollMotion()
	self:scrollTo(0, true)
end

---@param screen_x number
---@param screen_y number
---@return integer?
function RemoteCatalogList:getIndexAt(screen_x, screen_y)
	local local_y = self:getLocalY(screen_x, screen_y)
	if local_y < 0 or local_y >= self.height then
		return nil
	end
	local index = math.floor((local_y + self:getVisualScrollPosition()) / self:getRowStep()) + 1
	if index < 1 or index > #self.items then
		return nil
	end
	return index
end

---@param dt number
function RemoteCatalogList:update(dt)
	VirtualizedList.update(self, dt)
	self.hover_index = nil
	if self.mouse_over then
		self.hover_index = self:getIndexAt(love.mouse.getPosition())
	end
end

---@param e gui.MouseClickEvent
---@return boolean?
function RemoteCatalogList:onMouseClick(e)
	if e.button ~= 1 then
		return
	end
	local index = self:getIndexAt(e.x, e.y)
	if not index then
		return
	end
	self.selected_index = index
	if self.on_select then
		self.on_select(self.items[index], index)
	end
	return true
end

function RemoteCatalogList:draw()
	local scroll = self:getVisualScrollPosition()
	local first_index, last_index = self:getVisibleRowRange()
	for index = first_index, last_index do
		local item = self.items[index]
		local y = (index - 1) * self:getRowStep() - scroll
		local selected = index == self.selected_index
		local hovered = index == self.hover_index
		Painter.setColorTable((selected or hovered) and Colors.surface_raised
			or (index % 2 == 0 and Colors.surface or Colors.panel))
		love.graphics.rectangle("fill", 0, y, self.width, self.item_height, 5, 5)
		if selected then
			Painter.setColorTable(Colors.accent)
			love.graphics.rectangle("fill", 0, y, 5, self.item_height, 5, 5)
		end

		Painter.setColorTable(Colors.text)
		love.graphics.setFont(self.title_font)
		love.graphics.print(item.title .. "  /  " .. item.name, PADDING, y + 8)

		local mode = item.keys and (item.keys .. "K") or ("mode " .. item.mode)
		local details = ("%s  |  %s  |  %.2f  |  mapped by %s"):format(
			item.artist, mode, item.difficulty, item.creator
		)
		Painter.setColorTable(Colors.muted)
		love.graphics.setFont(self.detail_font)
		love.graphics.print(details, PADDING, y + 40)
	end
end

return RemoteCatalogList
