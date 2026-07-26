local View = require("gui.View")
local SpringValue = require("gui.anim.SpringValue")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Sounds = require("ui.Sounds")

---@class ui.screens.song_select.ChartSets : gui.View
---@operator call: ui.screens.song_select.ChartSets
local ChartSets = View + {}

local ITEM_HEIGHT = 76
local SCROLLBAR_PADDING = 0
local SCROLLBAR_WIDTH = 8
local SCROLLBAR_MIN_HEIGHT = 24
local SCROLL_RESET_DELAY = 1

---@param chartSelector rizu.select.ChartSelector
---@param on_selected fun(index: integer)
function ChartSets:new(chartSelector, on_selected)
	View.new(self)
	self.chartSelector = chartSelector
	self.on_selected = on_selected
	self.gap = 5
	self.scroll_spring = SpringValue({stiffness = 480, damping = 48})
	self.hover_index = nil
	self.scroll_offset = 0
	self.time_since_mouse_over = 0
	self.handles_mouse_input = true
	self.handles_keyboard_input = true
	self:setClip(true)
	self.batch = love.graphics.newSpriteBatch(Resources.atlas)
	self.title_batch = love.graphics.newTextBatch(Resources.getFont("cjk_bold", 24))
	self.artist_batch = love.graphics.newTextBatch(Resources.getFont("cjk_regular", 24))
	self.scrollbar_color = {Colors.text[1], Colors.text[2], Colors.text[3], 0.25}
	self.scrollbar_bg_color = {Colors.text_muted[1], Colors.text_muted[2], Colors.text_muted[3], 0.15}
end

function ChartSets:load() end

function ChartSets:onLayoutChanged(old_x, old_y, old_width, old_height)
	self.item_height = ITEM_HEIGHT
	self.cap_left_width = Painter.getQuadWidth(Resources.quads.list_item_cap_left)
	self.cap_right_width = Painter.getQuadWidth(Resources.quads.list_item_cap_right)
	self.mid_width = self.width - self.cap_left_width - self.cap_right_width
	self.stroke_left_width = Painter.getQuadWidth(Resources.quads.list_item_stroke_cap_left)
	self.stroke_right_width = Painter.getQuadWidth(Resources.quads.list_item_stroke_cap_right)
	self.stroke_height = Painter.getQuadHeight(Resources.quads.list_item_stroke_cap_left)
	local stroke_mid_width = Painter.getQuadWidth(Resources.quads.list_item_stroke_cap_middle)
	self.stroke_mid_scale = (self.width - self.stroke_left_width - self.stroke_right_width) / stroke_mid_width
	self.scroll_spring:snap(self.chartSelector.state:getPrimary().index * ITEM_HEIGHT)
end

function ChartSets:clampScroll(value)
	local store = self.chartSelector.stores[1]
	local item_count = store:count()
	local row_step = self.item_height + self.gap
	local max_scroll = math.max(0, (item_count - 1) * row_step)
	return math.max(0, math.min(value, max_scroll))
end

function ChartSets:update(dt)
	self.scroll_spring:update(dt)

	local store = self.chartSelector.stores[1]
	local item_count = store:count()
	local row_step = self.item_height + self.gap

	local last_hover = self.hover_index
	self.hover_index = nil
	if self.mouse_over then
		self.time_since_mouse_over = 0
		local _, my = self.world_transform:inverseTransformPoint(love.mouse.getPosition())
		if my >= 0 and my < self.height then
			local scroll = self.scroll_spring:get()
			local idx = math.floor((my + scroll) / row_step) + 1
			if idx >= 1 and idx <= item_count then
				self.hover_index = idx
			end
		end
	else
		self.time_since_mouse_over = math.min(SCROLL_RESET_DELAY, self.time_since_mouse_over + dt)
		if self.time_since_mouse_over == SCROLL_RESET_DELAY then
			self.scroll_offset = 0
		end
	end

	if last_hover ~= self.hover_index then
		Sounds.play("hover")
	end

	self.batch:clear()
	self.title_batch:clear()
	self.artist_batch:clear()

	local scroll = self.scroll_spring:get()
	local visible_rows = math.ceil(self.height / row_step) + 2

	local first_index = math.max(1, math.floor(scroll / row_step) - visible_rows)
	local last_index = math.min(item_count, math.ceil((scroll + self.height) / row_step) + visible_rows)
	local pixel_offset = scroll - (first_index - 1) * row_step

	local selected_index = self.chartSelector.state:getPrimary().index
	if selected_index ~= self.last_selected_index then
		self.last_selected_index = selected_index
		self.scroll_offset = 0
	end

	local base_target = (selected_index - 1) * row_step - (self.height / 2) + (row_step / 2)
	if self.mouse_over and love.mouse.isDown(2) then
		local _, my = self.world_transform:inverseTransformPoint(love.mouse.getPosition())
		local scroll_normal = math.max(0, math.min(1, my / self.height))
		self.scroll_offset = self:clampScroll((item_count - 1) * row_step) * scroll_normal - base_target
	end

	local target = base_target + self.scroll_offset
	self.scroll_spring:set(self:clampScroll(target))

	for i = first_index, last_index do
		local cv = store:get(i)
		if cv then
			local y = (i - first_index) * row_step - pixel_offset + self.gap / 2
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
	self.batch:add(Resources.quads.list_item_cap_left, 0, y)
	self.batch:add(Resources.quads.pixel, self.cap_left_width, y, 0, self.mid_width, self.item_height)
	self.batch:add(Resources.quads.list_item_cap_right, self.width - self.cap_right_width, y)

	if is_selected then
		local sy = y
		self.batch:setColor(Colors.accent)
		self.batch:add(Resources.quads.list_item_stroke_cap_left, 0, sy)
		self.batch:add(
			Resources.quads.list_item_stroke_cap_middle,
			self.stroke_left_width, sy, 0,
			self.stroke_mid_scale, 1
		)
		self.batch:add(Resources.quads.list_item_stroke_cap_right, self.width - self.stroke_right_width, sy)
	end

	copy_color_to_cs(Colors.text)
	cs[2] = cv.title or ""
	self.title_batch:add(cs, 24, y + 4)

	copy_color_to_cs(Colors.text_muted)
	cs[2] = cv.artist or ""
	self.artist_batch:add(cs, 24, y + 36)
end

function ChartSets:onScroll(e)
	local row_step = self.item_height + self.gap
	self.scroll_offset = self.scroll_offset - e.direction_y * row_step
	return true
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

function ChartSets:scrollToIndex(index)
	local row_step = self.item_height + self.gap
	local target = (index - 1) * row_step - (self.height / 2) + (row_step / 2)
	self.scroll_spring:set(self:clampScroll(target))
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

function ChartSets:drawScrollbar()
	local store = self.chartSelector.stores[1]
	local item_count = store:count()
	local row_step = self.item_height + self.gap
	local total_height = math.max(self.height, item_count * row_step)
	local max_scroll = self:clampScroll((item_count - 1) * row_step)

	local x = self.width - SCROLLBAR_PADDING - SCROLLBAR_WIDTH
	local y = SCROLLBAR_PADDING
	local h = math.max(0, self.height - SCROLLBAR_PADDING * 2)

	Painter.setColorTable(self.scrollbar_bg_color)
	lg.rectangle("fill", x, y, SCROLLBAR_WIDTH, h)

	local thumb_h = h
	if item_count > 0 then
		thumb_h = math.max(SCROLLBAR_MIN_HEIGHT, h * (self.height / total_height))
		thumb_h = math.min(h, thumb_h)
	end

	local thumb_y = y
	if max_scroll > 0 and h > thumb_h then
		thumb_y = y + (h - thumb_h) * (self.scroll_spring:get() / max_scroll)
	end

	Painter.setColorTable(self.scrollbar_color)
	lg.rectangle("fill", x, thumb_y, SCROLLBAR_WIDTH, thumb_h)
	Painter.setColorRgb(1, 1, 1)
end

function ChartSets:draw()
	lg.draw(self.batch)
	Painter.snapToPixel()
	lg.draw(self.title_batch)
	lg.draw(self.artist_batch)
	self:drawScrollbar()
end

return ChartSets
