local Colors = require("ui.Colors")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local VirtualizedList = require("gui.VirtualizedList")

---@class ui.screens.dlc.DlcList : gui.VirtualizedList
---@operator call: ui.screens.dlc.DlcList
---@field items table[]
---@field thumbnail_cache ui.screens.dlc.ThumbnailCache
---@field hover_index integer?
---@field on_download fun(item: table)?
---@field get_task fun(item: table): rizu.dlc.DlcTask?
local DlcList = VirtualizedList + {}

local ITEM_HEIGHT = 116
local PADDING = 12
local IMAGE_WIDTH = 230
local IMAGE_PADDING = 8
local FADE_DURATION = 0.35
local DOWNLOAD_BUTTON_WIDTH = 112
local DOWNLOAD_BUTTON_HEIGHT = 44
local DOWNLOAD_BUTTON_Y = 36

---@param thumbnail_cache ui.screens.dlc.ThumbnailCache
---@param on_download fun(item: table)?
---@param get_task fun(item: table): rizu.dlc.DlcTask?
function DlcList:new(thumbnail_cache, on_download, get_task)
	VirtualizedList.new(self)
	self.item_height = ITEM_HEIGHT
	self.gap = 8
	self.items = {}
	self.thumbnail_cache = thumbnail_cache
	self.on_download = on_download
	self.get_task = get_task or function() return nil end
	self.hover_index = nil
	self.title_font = Resources.getFont("cjk_bold", 24)
	self.detail_font = Resources.getFont("cjk_bold", 16)
	self.small_font = Resources.getFont("medium", 16)
	self.item_background = NineSliceUsage(Resources.nine_slices.dlc_list_item)
end

function DlcList:getItemCount()
	return #self.items
end

---@param items table[]
function DlcList:setItems(items)
	self.items = items
	self.hover_index = nil
	self:stopScrollMotion()
	self:scrollTo(0, true)
end

---@param screen_x number
---@param screen_y number
---@return integer?
function DlcList:getIndexAt(screen_x, screen_y)
	local local_y = self:getLocalY(screen_x, screen_y)
	if local_y < 0 or local_y >= self.height then return end
	local item_y = local_y + self:getVisualScrollPosition()
	local index = math.floor(item_y / self:getRowStep()) + 1
	if index < 1 or index > #self.items or item_y % self:getRowStep() >= self.item_height then return end
	return index
end

function DlcList:update(dt)
	VirtualizedList.update(self, dt)
	self.hover_index = nil
	if self.mouse_over then self.hover_index = self:getIndexAt(love.mouse.getPosition()) end
	local first_index, last_index = self:getVisibleRowRange()
	for index = first_index, last_index do
		local item = self.items[index]
		local url = item and item.thumbnail_url
		if url and not item.contains_nsfw then self.thumbnail_cache:get(url) end
	end
end

function DlcList:onMouseClick(e)
	if e.button ~= 1 then return end
	local index = self:getIndexAt(e.x, e.y)
	if not index then return end
	if self.get_task(self.items[index]) then return true end
	local local_x, local_y = self.world_transform:inverseTransformPoint(e.x, e.y)
	local row_y = local_y + self:getVisualScrollPosition() - (index - 1) * self:getRowStep()
	local button_x = self.width - DOWNLOAD_BUTTON_WIDTH - PADDING
	if local_x >= button_x and local_x <= button_x + DOWNLOAD_BUTTON_WIDTH
		and row_y >= DOWNLOAD_BUTTON_Y and row_y <= DOWNLOAD_BUTTON_Y + DOWNLOAD_BUTTON_HEIGHT
	then
		if self.on_download then self.on_download(self.items[index]) end
		return true
	end
end

---@param image love.Image
---@param y number
---@param opacity number
function DlcList:drawThumbnail(image, y, opacity)
	local lg = love.graphics
	local iw, ih = image:getDimensions()
	local preview_width = IMAGE_WIDTH - IMAGE_PADDING * 2
	local preview_height = self.item_height - IMAGE_PADDING * 2
	local scale = math.max(preview_width / iw, preview_height / ih)
	local draw_width, draw_height = iw * scale, ih * scale

	-- The cover uses a fill crop, so constrain it to its row preview slot.
	-- Scissors use drawable coordinates and are unaffected by the active transform.
	local x1, y1 = self.world_transform:transformPoint(IMAGE_PADDING, y + IMAGE_PADDING)
	local x2, y2 = self.world_transform:transformPoint(IMAGE_WIDTH - IMAGE_PADDING, y + self.item_height - IMAGE_PADDING)
	local old_x, old_y, old_width, old_height = lg.getScissor()
	lg.intersectScissor(
		math.min(x1, x2), math.min(y1, y2),
		math.abs(x2 - x1), math.abs(y2 - y1)
	)

	Painter.setOpacity(opacity)
	Painter.setColorRgb(1, 1, 1)
	lg.draw(image, IMAGE_PADDING + (preview_width - draw_width) / 2, y + IMAGE_PADDING + (preview_height - draw_height) / 2, 0, scale, scale)
	Painter.setOpacity(1)

	if old_x then
		lg.setScissor(old_x, old_y, old_width, old_height)
	else
		lg.setScissor()
	end
end

---@param background gui.NineSliceUsage
---@param x number
---@param y number
---@param width number
---@param height number
local function drawBackground(background, x, y, width, height)
	love.graphics.push("transform")
	love.graphics.translate(x, y)
	background:draw(width, height)
	love.graphics.pop()
end

function DlcList:draw()
	local scroll = self:getVisualScrollPosition()
	local first_index, last_index = self:getVisibleRowRange()
	local now = love.timer.getTime()
	for index = first_index, last_index do
		local item = self.items[index]
		local y = (index - 1) * self:getRowStep() - scroll
		local hovered = index == self.hover_index
		Painter.setColorTable(hovered and Colors.surface_raised or Colors.surface)
		drawBackground(self.item_background, 0, y, self.width, self.item_height)

		Painter.setColorTable(Colors.background)
		Resources.sprites.pixel:draw(IMAGE_PADDING, y + IMAGE_PADDING, 0, IMAGE_WIDTH - IMAGE_PADDING * 2, self.item_height - IMAGE_PADDING * 2)
		if item.contains_nsfw then
			Painter.setColorTable(Colors.danger)
			love.graphics.setFont(self.title_font)
			love.graphics.printf("NSFW", IMAGE_PADDING, y + (self.item_height - self.title_font:getHeight()) / 2,
				IMAGE_WIDTH - IMAGE_PADDING * 2, "center")
		else
			local image, downloaded_at
			if item.thumbnail_url then
				image, downloaded_at = self.thumbnail_cache:get(item.thumbnail_url, false)
			end
			if image then
				local opacity = math.min(1, math.max(0, (now - assert(downloaded_at)) / FADE_DURATION))
				self:drawThumbnail(image, y, opacity)
			end
		end

		local text_x = IMAGE_WIDTH + PADDING
		local title = item.title or item.name or "Unknown"
		local author = item.artist or item.author or "Unknown"
		local creator = item.creator and (" / " .. item.creator) or ""
		Painter.setColorTable(Colors.text)
		love.graphics.setFont(self.title_font)
		love.graphics.print(title, text_x, y + 13)
		Painter.setColorTable(Colors.muted)
		love.graphics.setFont(self.detail_font)
		love.graphics.print(author .. creator, text_x, y + 47)

		local details = item.total_songs and (tostring(item.total_songs) .. " Charts")
			or (item.status and tostring(item.status) or "Chart set")
		if item.size then details = details .. " • " .. tostring(item.size) end
		Painter.setColorTable(Colors.muted)
		love.graphics.setFont(self.small_font)
		love.graphics.print(details, text_x, y + 78)

		local button_x = self.width - DOWNLOAD_BUTTON_WIDTH - PADDING
		local task = self.get_task(item)
		Painter.setColorTable(task and Colors.surface_raised or (hovered and Colors.accent or Colors.outline))
		Resources.sprites.pixel:draw(button_x, y + DOWNLOAD_BUTTON_Y, 0, DOWNLOAD_BUTTON_WIDTH, DOWNLOAD_BUTTON_HEIGHT)
		Painter.setColorTable(task and Colors.muted or Colors.text)
		love.graphics.printf(task and task.status or "Download", button_x, y + DOWNLOAD_BUTTON_Y + 12, DOWNLOAD_BUTTON_WIDTH, "center")
	end
end

return DlcList
