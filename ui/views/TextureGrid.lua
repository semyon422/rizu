local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local VirtualizedList = require("gui.VirtualizedList")

---A grid of textures with their names. A cell's thumbnail is requested when the cell is drawn, one
---request at a time, and at most `limit` stay loaded: the ones drawn longest ago are released first.
---@class ui.views.TextureGrid : gui.VirtualizedList
---@operator call: ui.views.TextureGrid
---@field items any[] Values, one per cell.
---@field selected any
---@field hover_index integer?
---@field load fun(item: any): rizu.skin.SkinTextures.Thumbnail
---@field pending {item: any, request: rizu.skin.SkinTextures.Thumbnail, discarded: boolean?}?
---@field format fun(item: any): string
---@field on_select fun(item: any)
---@field limit integer
---@field images {[any]: {image: love.Image|false, drawn: integer}}
---@field loaded_count integer
---@field frame integer Counts draws, to find the images drawn longest ago.
local TextureGrid = VirtualizedList + {}

local CELL_WIDTH = 132
local IMAGE_SIZE = 116
local LABEL_HEIGHT = 24
local GAP = 12

---@param load fun(item: any): rizu.skin.SkinTextures.Thumbnail Starts decoding a small image of an item.
---@param format fun(item: any): string
---@param on_select fun(item: any)
---@param limit integer? Images loaded at once.
function TextureGrid:new(load, format, on_select, limit)
	VirtualizedList.new(self)
	self.item_height = IMAGE_SIZE + LABEL_HEIGHT
	self.gap = GAP
	self.items = {}
	self.selected = nil
	self.hover_index = nil
	self.load = load
	self.format = format
	self.on_select = on_select
	self.limit = limit or 64
	self.images = {}
	self.loaded_count = 0
	self.frame = 0
	self.font = Resources.getFont("regular", 14)
end

---@return integer
function TextureGrid:getItemCount()
	return #self.items
end

---@return integer
function TextureGrid:getColumnCount()
	return math.max(1, math.floor((self.width + GAP) / (CELL_WIDTH + GAP)))
end

---@param items any[]
---@param selected any
function TextureGrid:setItems(items, selected)
	self:clear()
	self.items = items
	self.selected = selected
	self:scrollTo(0, true)
end

---Releases every loaded image. A request still decoding is dropped when it finishes.
function TextureGrid:clear()
	for _, entry in pairs(self.images) do
		if entry.image then entry.image:release() end
	end
	self.images = {}
	self.loaded_count = 0
	if self.pending then self.pending.discarded = true end
end

---An item's image if it is loaded. Otherwise requests it, when no other request is decoding.
---@param item any
---@return love.Image?
function TextureGrid:getImage(item)
	local entry = self.images[item]
	if entry then
		entry.drawn = self.frame
		return entry.image or nil
	end
	if self.pending then return end
	local ok, request = pcall(self.load, item)
	if not ok then
		self.images[item] = {image = false, drawn = self.frame}
		return
	end
	self.pending = {item = item, request = request}
	self:poll() -- a request without a thread is done already
	entry = self.images[item]
	return entry and entry.image or nil
end

---Uploads the thumbnail of the pending request once it is decoded.
function TextureGrid:poll()
	local pending = self.pending
	if not pending or not pending.request.done then return end
	self.pending = nil
	local result = pending.request.result
	local data = result and result[1]
	if pending.discarded then
		if data then data:release() end
		return
	end
	local image = false ---@type love.Image|false
	if data then
		local ok, uploaded = pcall(love.graphics.newImage, data)
		image = ok and uploaded or false
		data:release()
	end
	self.images[pending.item] = {image = image, drawn = self.frame}
	if image then
		self.loaded_count = self.loaded_count + 1
		self:releaseOldest()
	end
end

function TextureGrid:releaseOldest()
	while self.loaded_count > self.limit do
		local oldest_item, oldest ---@type any, {image: love.Image|false, drawn: integer}?
		for item, entry in pairs(self.images) do
			-- Images drawn last frame are on screen too: this frame may not have reached them yet.
			if entry.image and entry.drawn < self.frame - 1 and (not oldest or entry.drawn < oldest.drawn) then
				oldest_item, oldest = item, entry
			end
		end
		-- Everything loaded is on screen: going over the limit beats blank cells.
		if not oldest then return end
		oldest.image:release()
		self.images[oldest_item] = nil
		self.loaded_count = self.loaded_count - 1
	end
end

---@param screen_x number
---@param screen_y number
---@return integer?
function TextureGrid:getIndexAt(screen_x, screen_y)
	local local_x, local_y = self.world_transform:inverseTransformPoint(screen_x, screen_y)
	if local_x < 0 or local_y < 0 or local_y >= self.height then return end
	local column = math.floor(local_x / (CELL_WIDTH + GAP))
	if column >= self:getColumnCount() or local_x - column * (CELL_WIDTH + GAP) > CELL_WIDTH then return end
	local row = math.floor((local_y + self:getVisualScrollPosition()) / self:getRowStep())
	local index = row * self:getColumnCount() + column + 1
	if self.items[index] ~= nil then return index end
end

function TextureGrid:update(dt)
	VirtualizedList.update(self, dt)
	self:poll()
	self.hover_index = self.mouse_over and self:getIndexAt(love.mouse.getPosition()) or nil
end

---@param e gui.MouseClickEvent
---@return boolean?
function TextureGrid:onMouseClick(e)
	if e.button ~= 1 or self.drag_active then return end
	local index = self:getIndexAt(e.x, e.y)
	if not index then return end
	self.on_select(self.items[index])
	return true
end

---@param text string
---@param width number
---@return string
function TextureGrid:fitText(text, width)
	if self.font:getWidth(text) <= width then return text end
	-- The end of a path tells textures apart better than its start.
	for start = 2, #text do
		local shortened = "…" .. text:sub(start)
		if self.font:getWidth(shortened) <= width then return shortened end
	end
	return text
end

function TextureGrid:draw()
	self.frame = self.frame + 1
	local columns = self:getColumnCount()
	local scroll = math.floor(self:getVisualScrollPosition() + 0.5)
	local first_row, last_row = self:getVisibleRowRange()
	local pixel = Resources.sprites.pixel
	love.graphics.setFont(self.font)
	for row = first_row, last_row do
		local y = (row - 1) * self:getRowStep() - scroll
		for column = 1, columns do
			local index = (row - 1) * columns + column
			local item = self.items[index]
			if item == nil then break end
			local x = (column - 1) * (CELL_WIDTH + GAP)
			local selected = item == self.selected
			Painter.setColorTable(selected and Colors.accent or index == self.hover_index and Colors.surface_raised
				or Colors.surface)
			pixel:draw(x, y, 0, CELL_WIDTH, self.item_height)
			Painter.setColorTable(Colors.background)
			local inset = (CELL_WIDTH - IMAGE_SIZE) / 2
			pixel:draw(x + inset, y + inset, 0, IMAGE_SIZE, IMAGE_SIZE - inset)

			local image = self:getImage(item)
			if image then
				local width, height = image:getDimensions()
				local box = IMAGE_SIZE - inset * 2
				local scale = math.min(box / width, box / height, 4)
				Painter.setColorRgb(1, 1, 1)
				love.graphics.draw(image, x + CELL_WIDTH / 2, y + inset + (IMAGE_SIZE - inset) / 2, 0, scale, scale,
					width / 2, height / 2)
			end
			Painter.setColorTable(selected and Colors.background or Colors.text)
			love.graphics.printf(self:fitText(self.format(item), CELL_WIDTH - 8), x + 4,
				y + IMAGE_SIZE + (LABEL_HEIGHT - self.font:getHeight()) / 2 - 2, CELL_WIDTH - 8, "center")
		end
	end
end

return TextureGrid
