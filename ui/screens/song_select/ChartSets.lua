local VirtualizedList = require("gui.VirtualizedList")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local SpriteBatch = require("gui.SpriteBatch")
local Sounds = require("ui.Sounds")

---@class ui.screens.song_select.ChartSets : gui.VirtualizedList
---@operator call: ui.screens.song_select.ChartSets
local ChartSets = VirtualizedList + {}

local ITEM_HEIGHT = 76
local SCROLL_RETURN_DELAY = 2

---@param chartSelector rizu.select.ChartSelector
---@param on_selected fun(index: integer)
function ChartSets:new(chartSelector, on_selected)
	VirtualizedList.new(self)
	self.chartSelector = chartSelector
	self.on_selected = on_selected
	self.gap = 5
	self.item_height = ITEM_HEIGHT
	self.hover_index = nil
	self.scroll_return_elapsed = 0
	self.scroll_return_pending = false
	self.handles_keyboard_input = true
	self.batch = SpriteBatch(Resources.sprites.list_item_cap_left)
	self.title_batch = love.graphics.newTextBatch(Resources.getFont("cjk_bold", 24))
	self.artist_batch = love.graphics.newTextBatch(Resources.getFont("cjk_regular", 24))
end

function ChartSets:load() end

function ChartSets:onLayoutChanged(old_x, old_y, old_width, old_height)
	self.item_height = ITEM_HEIGHT
	self.cap_left_width = Resources.sprites.list_item_cap_left:getWidth()
	self.cap_right_width = Resources.sprites.list_item_cap_right:getWidth()
	self.mid_width = self.width - self.cap_left_width - self.cap_right_width
	self.stroke_left_width = Resources.sprites.list_item_stroke_cap_left:getWidth()
	self.stroke_right_width = Resources.sprites.list_item_stroke_cap_right:getWidth()
	self.stroke_height = Resources.sprites.list_item_stroke_cap_left:getHeight()
	local stroke_mid_width = Resources.sprites.list_item_stroke_cap_middle:getWidth()
	self.stroke_mid_scale = (self.width - self.stroke_left_width - self.stroke_right_width) / stroke_mid_width
	self:scrollToIndex(self.chartSelector.state:getPrimary().index, true)
end

---@return integer count
function ChartSets:getItemCount()
	return self.chartSelector.stores[1]:count()
end

---@private
function ChartSets:markScrollActivity()
	self.scroll_return_elapsed = 0
	self.scroll_return_pending = true
end

function ChartSets:update(dt)
	VirtualizedList.update(self, dt)

	local store = self.chartSelector.stores[1]
	local item_count = store:count()
	local row_step = self.item_height + self.gap

	local last_hover = self.hover_index
	self.hover_index = nil
	if self.mouse_over then
		local _, my = self.world_transform:inverseTransformPoint(love.mouse.getPosition())
		if my >= 0 and my < self.height then
			local scroll = self:getVisualScrollPosition()
			local idx = math.floor((my + scroll) / row_step) + 1
			if idx >= 1 and idx <= item_count then
				self.hover_index = idx
			end
		end
	end

	if last_hover ~= self.hover_index then
		Sounds.play("hover")
	end

	self.batch:clear()
	self.title_batch:clear()
	self.artist_batch:clear()

	local selected_index = self.chartSelector.state:getPrimary().index
	if selected_index ~= self.last_selected_index then
		self.last_selected_index = selected_index
		self.scroll_return_pending = false
		self:scrollToIndex(selected_index)
	end

	if self.mouse_over and love.mouse.isDown(2) then
		local _, mouse_y = self.world_transform:inverseTransformPoint(love.mouse.getPosition())
		local scroll_normal = math.min(math.max(mouse_y / self.height, 0), 1)
		self:markScrollActivity()
		self:stopScrollMotion()
		self:scrollTo(self:getMaxScroll() * scroll_normal, true)
	elseif self.scroll_return_pending and not self.drag_active then
		self.scroll_return_elapsed = self.scroll_return_elapsed + dt
		if self.scroll_return_elapsed >= SCROLL_RETURN_DELAY then
			self.scroll_return_pending = false
			self:stopScrollMotion()
			self:scrollToIndex(selected_index)
		end
	end

	local scroll = self:getVisualScrollPosition()
	local first_index, last_index = self:getVisibleRowRange()
	for i = first_index, last_index do
		local cv = store:get(i)
		if cv then
			local y = (i - 1) * row_step - scroll + self.gap / 2
			self:drawItem(cv, i, y, i == selected_index, i == self.hover_index)
		end
	end
end

local cs = {{1, 1, 1, 1}, ""}

---@param color gui.Color
local function copy_color_to_cs(color)
	cs[1][1] = color[1]
	cs[1][2] = color[2]
	cs[1][3] = color[3]
	cs[1][4] = color[4]
end

---@param cv rizu.library.LocatedChartview
---@param index integer
---@param y number
---@param is_selected boolean
---@param is_hovered boolean
function ChartSets:drawItem(cv, index, y, is_selected, is_hovered)
	local panel_color = index % 2 == 0 and Colors.panel or Colors.panel_alt
	if is_hovered then
		self.batch:setColor(Colors.hover)
	else
		self.batch:setColor(panel_color)
	end
	self.batch:add(Resources.sprites.list_item_cap_left, 0, y)
	self.batch:add(Resources.sprites.pixel, self.cap_left_width, y, 0, self.mid_width, self.item_height)
	self.batch:add(Resources.sprites.list_item_cap_right, self.width - self.cap_right_width, y)

	if is_selected then
		local sy = y
		self.batch:setColor(Colors.accent)
		self.batch:add(Resources.sprites.list_item_stroke_cap_left, 0, sy)
		self.batch:add(
			Resources.sprites.list_item_stroke_cap_middle,
			self.stroke_left_width, sy, 0,
			self.stroke_mid_scale, 1
		)
		self.batch:add(Resources.sprites.list_item_stroke_cap_right, self.width - self.stroke_right_width, sy)
	end

	copy_color_to_cs(Colors.text)
	cs[2] = cv.title or ""
	self.title_batch:add(cs, 24, y + 4)

	copy_color_to_cs(Colors.text_muted)
	cs[2] = cv.artist or ""
	self.artist_batch:add(cs, 24, y + 36)
end

---@param e gui.ScrollEvent
---@return boolean handled
function ChartSets:onScroll(e)
	self:markScrollActivity()
	return VirtualizedList.onScroll(self, e)
end

---@param e gui.DragStartEvent
---@return boolean? handled
function ChartSets:onDragStart(e)
	local handled = VirtualizedList.onDragStart(self, e)
	if handled then
		self:markScrollActivity()
	end
	return handled
end

---@param e gui.DragEvent
---@return boolean? handled
function ChartSets:onDrag(e)
	local handled = VirtualizedList.onDrag(self, e)
	if handled then
		self:markScrollActivity()
	end
	return handled
end

function ChartSets:onKeyDown(e)
	if e.key == "j" then
		self.chartSelector:scrollLevel(1, 1)
		Sounds.play("set_changed")
		return true
	elseif e.key == "k" then
		self.chartSelector:scrollLevel(1, -1)
		Sounds.play("set_changed")
		return true
	end
end

---@param index integer
---@param immediate boolean?
function ChartSets:scrollToIndex(index, immediate)
	local row_step = self.item_height + self.gap
	local target = (index - 1) * row_step - (self.height / 2) + (row_step / 2)
	self:scrollTo(target, immediate)
end

function ChartSets:onMouseClick(e)
	if e.button == 1 and self.hover_index then
		self.chartSelector:scrollLevel(1, nil, self.hover_index)
		self:scrollToIndex(self.hover_index)
		self.on_selected(self.hover_index)
		Sounds.play("set_changed")
		return true
	end
end

local lg = love.graphics

function ChartSets:draw()
	self.batch:draw()
	Painter.snapToPixel()
	lg.draw(self.title_batch)
	lg.draw(self.artist_batch)
end

return ChartSets
