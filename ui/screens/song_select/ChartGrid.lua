local VirtualizedList = require("gui.VirtualizedList")
local Resources = require("ui.Resources")
local Painter = require("gui.Painter")
local Colors = require("ui.Colors")
local Sounds = require("ui.Sounds")
local ChartviewFormatter = require("ui.formatters.ChartviewFormatter")
local Settings = require("rizu.config.Settings")

---@class ui.screens.song_select.ChartGrid.Item
---@field id integer
---@field difficulty string
---@field difficulty_color gui.Color
---@field inputmode string

---@class ui.screens.song_select.ChartGrid : gui.VirtualizedList
---@operator call: ui.screens.song_select.ChartGrid
---@field items ui.screens.song_select.ChartGrid.Item[]
---@field hover_id integer?
---@field chartview_formatter ui.formatters.ChartviewFormatter
local ChartGrid = VirtualizedList + {}

local ITEM_WIDTH = 110
local ITEM_GAP = 5
local ITEM_HEIGHT = 66

---@param chart_selector rizu.select.ChartSelector
function ChartGrid:new(chart_selector)
	VirtualizedList.new(self)
	self.chart_selector = chart_selector
	self.chartview_formatter = ChartviewFormatter(nil, chart_selector.settings)
	self.items = {}
	self.meta_batch = love.graphics.newTextBatch(Resources.getFont("regular", 24)) ---@type love.Text
	self.inputmode_batch = love.graphics.newTextBatch(Resources.getFont("regular", 16)) ---@type love.Text
	self.item_height = ITEM_HEIGHT
	self.gap = ITEM_GAP
	self.drag_axis = "horizontal"
	self.handles_keyboard_input = true
	self.reload_items_needed = true

	chart_selector.settings:subscribeChoice(Settings.keys.select.diff_column, function()
		self:requestReloadItems()
	end)
	chart_selector.stores[2]:onChanged(function()
		self:requestReloadItems()
	end)
end

function ChartGrid:load() end

function ChartGrid:onLayoutChanged(old_x, old_y, old_width, old_height)
	self:scrollToSelected(true)
end

---@return integer count
function ChartGrid:getItemCount()
	return #self.items
end

---@return number size
function ChartGrid:getScrollContentSize()
	if #self.items == 0 then
		return 0
	end
	return #self.items * ITEM_WIDTH + (#self.items - 1) * ITEM_GAP
end

---@return number size
function ChartGrid:getScrollViewportSize()
	return self.width
end

function ChartGrid:getLocalY(screen_x, screen_y)
	local local_x = self.world_transform:inverseTransformPoint(screen_x, screen_y)
	return local_x
end

function ChartGrid:reloadItems()
	self.items = {}
	local secondary = self.chart_selector.stores[2]
	local count = secondary:count()

	for i = 1, count do
		local item = secondary:get(i)
		if item then
			self.chartview_formatter:setChartview(item)
			local difficulty = self.chartview_formatter:getDifficulty()
			table.insert(self.items, {
				id = i,
				difficulty = difficulty.value,
				difficulty_color = difficulty.color,
				inputmode = (item.inputmode or "?"):gsub("key", "K"):gsub("scratch", "S")
			})
		end
	end
end

function ChartGrid:requestReloadItems()
	self.reload_items_needed = true
end

---@param immediate boolean?
function ChartGrid:scrollToSelected(immediate)
	local selected_index = self.chart_selector.state:getSecondary().index
	local selected_x = math.max(0, (selected_index - 1) * (ITEM_WIDTH + ITEM_GAP))
	self:scrollTo(selected_x - (self.width - ITEM_WIDTH) / 2, immediate)
end

function ChartGrid:onScroll(e)
	self:scrollTo(self.scroll_target - e.direction_y * (ITEM_WIDTH + ITEM_GAP))
	return true
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
	VirtualizedList.update(self, dt)
	if self.reload_items_needed then
		self.reload_items_needed = false
		self:reloadItems()
	end

	local last_hover = self.hover_id
	self.hover_id = nil
	if self.mouse_over then
		local mx, my = self.world_transform:inverseTransformPoint(love.mouse.getPosition())
		if mx >= 0 and mx < self.width and my >= 0 and my < self.height then
			local scroll = self:getVisualScrollPosition()
			local item_x = mx + scroll
			local idx = math.floor(item_x / (ITEM_WIDTH + ITEM_GAP)) + 1
			if idx >= 1 and idx <= #self.items
				and item_x % (ITEM_WIDTH + ITEM_GAP) < ITEM_WIDTH
			then
				self.hover_id = self.items[idx].id
			end
		end
	end

	if last_hover ~= self.hover_id then
		Sounds.play("hover")
	end

	self.meta_batch:clear()
	self.inputmode_batch:clear()

	local scroll = self:getVisualScrollPosition()
	local item_step = ITEM_WIDTH + ITEM_GAP
	local first_index = math.max(1, math.floor(scroll / item_step) + 1)
	local last_index = math.min(#self.items, math.floor((scroll + self.width) / item_step) + 1)

	for i = first_index, last_index do
		local v = self.items[i]
		local x = (i - 1) * item_step - scroll

		if v then
			cs[1] = v.difficulty_color
			cs[2] = v.difficulty
			local difficulty_font = self.meta_batch:getFont()
			local inputmode_font = self.inputmode_batch:getFont()
			local gap = 8
			local content_width = difficulty_font:getWidth(v.difficulty) + gap + inputmode_font:getWidth(v.inputmode)
			local difficulty_x = x + (ITEM_WIDTH - content_width) / 2
			self.meta_batch:add(cs, difficulty_x, 18)
			self.inputmode_batch:add(v.inputmode, difficulty_x + difficulty_font:getWidth(v.difficulty) + gap, 23)
		end
	end
end

local lg = love.graphics

function ChartGrid:draw()
	local scroll = self:getVisualScrollPosition()
	local item_step = ITEM_WIDTH + ITEM_GAP
	local first_index = math.max(1, math.floor(scroll / item_step) + 1)
	local last_index = math.min(#self.items, math.floor((scroll + self.width) / item_step) + 1)
	local selected_index = self.chart_selector.state:getSecondary().index

	for i = first_index, last_index do
		local item = self.items[i]
		if item then
			local x = (i - 1) * item_step - scroll
			local selected = selected_index == item.id
			Painter.setColorTable((selected or self.hover_id == item.id) and Colors.surface_raised or Colors.surface)
			Resources.sprites.pixel:draw(x, 0, 0, ITEM_WIDTH, ITEM_HEIGHT)
			if selected then
				Painter.setColorTable(item.difficulty_color)
				Resources.sprites.pixel:draw(x, ITEM_HEIGHT - 3, 0, ITEM_WIDTH, 3)
			end
		end
	end

	Painter.setColorRgb(1, 1, 1)
	lg.draw(self.meta_batch)
	lg.draw(self.inputmode_batch)
end
return ChartGrid
