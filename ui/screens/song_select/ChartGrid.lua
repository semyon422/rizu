local View = require("gui.View")
local SpringValue = require("gui.anim.SpringValue")
local Resources = require("ui.Resources")
local Painter = require("gui.Painter")
local Colors = require("ui.Colors")
local Color = require("ui.Color")
local Sounds = require("ui.Sounds")

---@class ui.screens.song_select.ChartGrid.Item
---@field id integer
---@field difficulty string
---@field difficulty_color gui.Color
---@field inputmode string
---@field name string

---@class ui.screens.song_select.ChartGrid : gui.View
---@operator call: ui.screens.song_select.ChartGrid
---@field items ui.screens.song_select.ChartGrid.Item[]
---@field cap love.Quad
---@field body love.Quad
---@field stroke_left love.Quad
---@field stroke_middle love.Quad
---@field stroke_right love.Quad
---@field cap_w number
---@field body_w number
---@field stroke_left_w number
---@field stroke_middle_w number
---@field stroke_right_w number
---@field body_s number
---@field stroke_middle_s number
---@field hover_id integer?
local ChartGrid = View + {}

local COL_WIDTH = 345
local COL_X_GAP = 5
local COL_Y_GAP = 5
local ROW_HEIGHT = 42 + COL_Y_GAP
local SCROLLBAR_PADDING = 0
local SCROLLBAR_WIDTH = 8
local SCROLLBAR_THUMB_HEIGHT = 24

---@param chart_selector rizu.select.ChartSelector
function ChartGrid:new(chart_selector)
	View.new(self)
	self.chart_selector = chart_selector
	self.items = {}
	self.meta_batch = love.graphics.newTextBatch(Resources.getFont("regular", 24)) ---@type love.Text
	self.names_batch = love.graphics.newTextBatch(Resources.getFont("cjk_regular", 24)) ---@type love.Text
	self.batch = love.graphics.newSpriteBatch(Resources.atlas)
	self.scroll_spring = SpringValue({stiffness = 480, damping = 48})
	self.scroll_offset = 0
	self.scrollbar_color = {Colors.text[1], Colors.text[2], Colors.text[3], 0.25}
	self.scrollbar_bg_color = {Colors.text_muted[1], Colors.text_muted[2], Colors.text_muted[3], 0.15}
	self.handles_mouse_input = true
	self.handles_keyboard_input = true
	self.clip = true

	self.cap = Resources.quads.grid_item_cap_right
	self.body = Resources.quads.grid_item_body
	self.stroke_left = Resources.quads.grid_item_stroke_left
	self.stroke_middle = Resources.quads.grid_item_stroke_middle
	self.stroke_right = Resources.quads.grid_item_stroke_right
	self.cap_w = Painter.getQuadWidth(self.cap)
	self.body_w = Painter.getQuadWidth(self.body)
	self.stroke_left_w = Painter.getQuadWidth(self.stroke_left)
	self.stroke_middle_w = Painter.getQuadWidth(self.stroke_middle)
	self.stroke_right_w = Painter.getQuadWidth(self.stroke_right)
end

function ChartGrid:load() end

function ChartGrid:onLayoutChanged(old_x, old_y, old_width, old_height)
	local w, h = self.width, self.height

	local cols = math.max(1, math.floor(w / COL_WIDTH))
	local total_gap_x = COL_X_GAP * (cols - 1)
	local width_per_col = (w - total_gap_x) / cols

	self.columns = cols
	self.height = h
	self.width_per_col = width_per_col
	self.body_s = (width_per_col - self.cap_w) / self.body_w
	self.stroke_middle_s = (width_per_col - self.stroke_left_w - self.stroke_right_w) / self.stroke_middle_w
end

function ChartGrid:clampScroll(value)
	local total_rows = math.max(1, math.ceil(#self.items / self.columns))
	local visible_rows = math.max(1, math.ceil(self.height / ROW_HEIGHT))
	local max_scroll = math.max(0, (total_rows - visible_rows) * ROW_HEIGHT)
	return math.max(0, math.min(value, max_scroll))
end

function ChartGrid:reloadItems()
	self.items = {}
	local secondary = self.chart_selector.stores[2]
	local count = secondary:count()

	for i = 1, count do
		local item = secondary:get(i)
		if item then
			local enps = item.enps_diff or 0
			table.insert(self.items, {
				id = i,
				name = item.name or "Unknown",
				difficulty = ("%0.01f"):format(enps),
				difficulty_color = Color.enpsToColor(enps, {1, 1, 1, 1}),
				inputmode = (item.inputmode or "?"):gsub("key", "K"):gsub("scratch", "S")
			})
		end
	end
end

function ChartGrid:requestReloadItems()
	self.reload_items_needed = true
end

function ChartGrid:onScroll(e)
	self.scroll_offset = self:clampScroll(self.scroll_offset - e.direction_y * ROW_HEIGHT)
	return true
end

function ChartGrid:scrollToSelected()
	local selected_index = self.chart_selector.state:getSecondary().index
	local selected_row = math.max(0, math.floor((selected_index - 1) / self.columns))
	self.scroll_offset = self:clampScroll(selected_row * ROW_HEIGHT - (self.height / 2) + (ROW_HEIGHT / 2) - COL_Y_GAP)
end

function ChartGrid:onKeyDown(e)
	if e.key == "h" then
		self.chart_selector:scrollLevel(2, -1)
		Sounds.play("chart_changed")
		self:scrollToSelected()
		return true
	elseif e.key == "l" then
		self.chart_selector:scrollLevel(2, 1)
		Sounds.play("chart_changed")
		self:scrollToSelected()
		return true
	end
end

function ChartGrid:onMouseClick(e)
	if e.button == 1 and self.hover_id then
		self.chart_selector:scrollLevel(2, 0, self.hover_id)
		Sounds.play("chart_changed")
		return true
	end
end

local cs = {{1, 1, 1, 1}, ""}

function ChartGrid:update(dt)
	if self.reload_items_needed then
		self.reload_items_needed = false
		self:reloadItems()
	end

	self.scroll_spring:update(dt)
	self.scroll_spring:set(self:clampScroll(self.scroll_offset))

	local last_hover = self.hover_id
	self.hover_id = nil
	if self.mouse_over then
		local mx, my = self.world_transform:inverseTransformPoint(love.mouse.getPosition())
		if mx >= 0 and mx < self.width and my >= 0 and my < self.height then
			local scroll = self.scroll_spring:get()
			local col = math.floor(mx / (self.width_per_col + COL_X_GAP))
			local row = math.floor((my + scroll) / ROW_HEIGHT)
			local idx = (row * self.columns + col) + 1
			if idx >= 1 and idx <= #self.items then
				self.hover_id = self.items[idx].id
			end
		end
	end

	if last_hover ~= self.hover_id then
		Sounds.play("hover")
	end

	self.meta_batch:clear()
	self.names_batch:clear()
	self.batch:clear()

	local batch = self.batch

	local scroll = self.scroll_spring:get()
	local selected_index = self.chart_selector.state:getSecondary().index

	for i, v in ipairs(self.items) do
		local col = (i - 1) % self.columns
		local row = math.floor((i - 1) / self.columns)
		local x = col * (self.width_per_col + COL_X_GAP)
		local y = row * ROW_HEIGHT - scroll
		local c = v.difficulty_color
		local is_selected = selected_index == v.id
		local is_hovered = self.hover_id == v.id

		batch:setColor(c[1], c[2], c[3], (is_selected or is_hovered) and 0.4 or 0.2)
		batch:add(self.body, x, y, 0, self.body_s, 1)
		batch:add(self.cap, x + (self.body_w * self.body_s), y)

		if is_selected then
			batch:setColor(Colors.accent)
			batch:add(self.stroke_left, x, y)
			batch:add(self.stroke_middle, x + self.stroke_left_w, y, 0, self.stroke_middle_s, 1)
			batch:add(self.stroke_right, x + self.width_per_col - self.stroke_right_w, y)
		end

		cs[1] = v.difficulty_color
		cs[2] = v.difficulty
		self.meta_batch:add(cs, x + 12, y + 7)
		self.meta_batch:add(v.inputmode, x + 86, y + 7)
		self.names_batch:add(v.name, x + 134, y + 1)
	end
end

local lg = love.graphics

function ChartGrid:drawScrollbar()
	local total_rows = math.max(1, math.ceil(#self.items / self.columns))
	if total_rows <= 3 then
		return
	end

	local visible_rows = math.max(1, math.ceil(self.height / ROW_HEIGHT))
	local max_scroll = math.max(0, (total_rows - visible_rows) * ROW_HEIGHT)

	local x = self.width - SCROLLBAR_PADDING - SCROLLBAR_WIDTH
	local y = SCROLLBAR_PADDING
	local h = math.max(0, self.height - SCROLLBAR_PADDING * 2)

	Painter.setColorTable(self.scrollbar_bg_color)
	lg.rectangle("fill", x, y, SCROLLBAR_WIDTH, h)

	local thumb_h = SCROLLBAR_THUMB_HEIGHT
	local thumb_y = y
	if max_scroll > 0 then
		thumb_y = y + (h - thumb_h) * (self.scroll_spring:get() / max_scroll)
	end

	Painter.setColorTable(self.scrollbar_color)
	lg.rectangle("fill", x, thumb_y, SCROLLBAR_WIDTH, thumb_h)
	Painter.setColorRgb(1, 1, 1)
end

function ChartGrid:draw()
	Painter.setColorRgb(1, 1, 1)
	lg.draw(self.batch)
	lg.draw(self.meta_batch)
	lg.draw(self.names_batch)
	self:drawScrollbar()
end
return ChartGrid
