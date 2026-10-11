local utf8 = require("utf8")
local VirtualizedList = require("gui.VirtualizedList")
local Resources = require("ui.Resources")
local Painter = require("gui.Painter")
local Colors = require("ui.Colors")
local Sounds = require("ui.Sounds")
local ChartviewFormatter = require("ui.formatters.ChartviewFormatter")
local Settings = require("rizu.config.Settings")

---@class ui.screens.song_select_v2.ChartGrid.Item
---@field id integer
---@field difficulty string
---@field difficulty_color gui.Color
---@field name string Shown in the tooltip.
---@field mode string Shown on the tab: gamemode, or the keymode for mania.

---@class ui.screens.song_select_v2.ChartGrid : gui.VirtualizedList
---@operator call: ui.screens.song_select_v2.ChartGrid
---@field items ui.screens.song_select_v2.ChartGrid.Item[]
---@field hover_id integer?
---@field hover_name string?
---@field chartview_formatter ui.formatters.ChartviewFormatter
---@field tooltip ui.views.Tooltip?
local ChartGrid = VirtualizedList + {}

local ITEM_WIDTH = 160
local ITEM_GAP = 5
local ITEM_HEIGHT = 56
local TEXT_PADDING = 20
local TEXT_GAP = 10
-- Height of the selected tab's bottom stroke, see chart_grid_tab_selected.
local STROKE_HEIGHT = 3
local SELECTED_GRADIENT_OPACITY = 0.32

---@param chart_selector rizu.select.ChartSelector
---@param tooltip ui.views.Tooltip?
---@param localization ui.localization.Localization
function ChartGrid:new(chart_selector, tooltip, localization)
	VirtualizedList.new(self)
	self.chart_selector = chart_selector
	self.tooltip = tooltip
	self.localization = localization
	self.chartview_formatter = ChartviewFormatter(nil, chart_selector.settings)
	self.items = {}
	self.difficulty_batch = love.graphics.newTextBatch(Resources.getFont("bold", 24)) ---@type love.Text
	self.name_batch = love.graphics.newTextBatch(Resources.getFont("regular", 20)) ---@type love.Text
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
				mode = (self.chartview_formatter:getMode():gsub(" %(EXPERIMENTAL%)$", "")),
				name = self.chartview_formatter:getName() or (self.localization:get("song_select.unknown_difficulty")),
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

---@param font love.Font
---@param text string
---@param max_width number
---@return string
local function fitText(font, text, max_width)
	if font:getWidth(text) <= max_width then
		return text
	end
	while #text > 0 and font:getWidth(text .. "…") > max_width do
		text = text:sub(1, utf8.offset(text, -1) - 1)
	end
	return text .. "…"
end

function ChartGrid:update(dt)
	VirtualizedList.update(self, dt)
	if self.reload_items_needed then
		self.reload_items_needed = false
		self:reloadItems()
	end

	local last_hover = self.hover_id
	self.hover_id = nil
	self.hover_name = nil
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
				self.hover_name = self.items[idx].name
			end
		end
	end

	if last_hover ~= self.hover_id then
		Sounds.play("hover")
		if self.tooltip then
			self.tooltip:setText(self.hover_name)
		end
	end
	if self.hover_id and self.tooltip then
		self.tooltip:followCursor(love.mouse.getPosition())
	end

	self.difficulty_batch:clear()
	self.name_batch:clear()

	local scroll = self:getVisualScrollPosition()
	local item_step = ITEM_WIDTH + ITEM_GAP
	local first_index = math.max(1, math.floor(scroll / item_step) + 1)
	local last_index = math.min(#self.items, math.floor((scroll + self.width) / item_step) + 1)

	for i = first_index, last_index do
		local v = self.items[i]
		local x = (i - 1) * item_step - scroll

		if v then
			local difficulty_font = self.difficulty_batch:getFont()
			local name_font = self.name_batch:getFont()
			-- Same baseline for both sizes.
			local baseline = (ITEM_HEIGHT + difficulty_font:getHeight()) / 2 - 4 - STROKE_HEIGHT
			cs[1] = v.difficulty_color
			cs[2] = v.difficulty
			local text_x = x + TEXT_PADDING
			self.difficulty_batch:add(cs, text_x, baseline - difficulty_font:getBaseline())
			-- Centered between the difficulty and the right edge of the tab.
			local area_x = text_x + difficulty_font:getWidth(v.difficulty) + TEXT_GAP
			local area_width = x + ITEM_WIDTH - TEXT_PADDING / 2 - area_x
			local mode = fitText(name_font, v.mode, area_width)
			local name_x = area_x + (area_width - name_font:getWidth(mode)) / 2
			cs[1] = Colors.muted
			cs[2] = mode
			self.name_batch:add(cs, name_x, baseline - name_font:getBaseline())
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
			Resources.sprites.chart_grid_tab:draw(x, 0)
			if selected then
				-- Difficulty colour fading out from the bottom stroke upwards.
				local color = item.difficulty_color
				Painter.setColorRgb(color[1], color[2], color[3], SELECTED_GRADIENT_OPACITY)
				Resources.sprites.chart_grid_tab_gradient:draw(x, 0)
				Painter.setColorTable(item.difficulty_color)
				Resources.sprites.chart_grid_tab_selected:draw(x, 0)
			end
		end
	end

	Painter.setColorRgb(1, 1, 1)
	lg.draw(self.difficulty_batch)
	lg.draw(self.name_batch)
end
return ChartGrid
