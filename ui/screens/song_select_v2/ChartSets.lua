local VirtualizedList = require("gui.VirtualizedList")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local SpriteBatch = require("gui.SpriteBatch")
local NineSliceUsage = require("gui.NineSliceUsage")
local Sounds = require("ui.Sounds")
local Color = require("ui.Color")
local Settings = require("rizu.config.Settings")

---@class ui.screens.song_select_v2.ChartSets : gui.VirtualizedList
---@operator call: ui.screens.song_select_v2.ChartSets
local ChartSets = VirtualizedList + {}

local ITEM_HEIGHT = 76
local SCROLL_RETURN_DELAY = 2
-- Colours follow result_design/select.css: .song and .song.on. The tint is dimmer than the CSS.
local BASE_ALPHA = 0.72
local HOVER_ALPHA = 0.85
local SELECTED_ALPHA = 0.95
local TINT_ALPHA = 0.12
local TINT_LENGTH = 0.45
local SELECTED_TINT_ALPHA = 0.20
local SELECTED_TINT_LENGTH = 0.60

---@param chartSelector rizu.select.ChartSelector
---@param settings rizu.config.Config
---@param on_selected fun(index: integer)
function ChartSets:new(chartSelector, settings, on_selected)
	VirtualizedList.new(self)
	self.chartSelector = chartSelector
	self.settings = settings
	self.on_selected = on_selected
	self.gap = 5
	self.item_height = ITEM_HEIGHT
	self.hover_index = nil
	self.scroll_return_elapsed = 0
	self.scroll_return_pending = false
	self.handles_keyboard_input = true
	-- Generated and packed sprites live in different atlases, so each needs its own batch.
	self.background_batch = SpriteBatch(Resources.sprites.song_set_body)
	self.batch = SpriteBatch(Resources.sprites.chart_sets_difficulty)
	self.outline = NineSliceUsage(Resources.nine_slices.song_set_outline)
	self.title_batch = love.graphics.newTextBatch(Resources.getFont("cjk_bold", 24))
	self.artist_batch = love.graphics.newTextBatch(Resources.getFont("cjk_regular", 24))

end

function ChartSets:load() end

function ChartSets:onLayoutChanged(old_x, old_y, old_width, old_height)
	self.item_height = ITEM_HEIGHT
	self.cap_width = Resources.sprites.song_set_cap_left:getWidth()
	self.mid_width = self.width - self.cap_width * 2
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

	self.background_batch:clear()
	self.outline_y = nil
	self.batch:clear()
	self.title_batch:clear()
	self.artist_batch:clear()

	local selected_index = self.chartSelector.state:getPrimary().index
	if selected_index ~= self.last_selected_index then
		self.last_selected_index = selected_index
		self.scroll_return_pending = false
		self:scrollToIndex(selected_index)
	end

	if self.mouse_over then
		self:markScrollActivity()
	end

	if self.mouse_over and love.mouse.isDown(2) then
		local _, mouse_y = self.world_transform:inverseTransformPoint(love.mouse.getPosition())
		local scroll_normal = math.min(math.max(mouse_y / self.height, 0), 1)
		self:stopScrollMotion()
		self:scrollTo(self:getMaxScroll() * scroll_normal)
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
local diff_color = {0, 0, 0, 0}

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
	local diff_column = self.settings:getChoice(Settings.keys.select.diff_column)
	local diff = cv[diff_column] ---@type number?

	if diff then
		Color.diffToColor(diff_column, diff, diff_color)
		diff_color[4] = 1
	else
		diff_color[4] = 0
	end

	local sprites = Resources.sprites
	local background = self.background_batch
	local base = Colors.panel
	local alpha = BASE_ALPHA
	if is_selected then
		base, alpha = Colors.surface, SELECTED_ALPHA
	elseif is_hovered then
		base, alpha = Colors.surface_raised, HOVER_ALPHA
	end
	background:setColor(base[1], base[2], base[3], alpha)
	background:add(sprites.song_set_cap_left, 0, y)
	background:add(sprites.song_set_body, self.cap_width, y, 0, self.mid_width / sprites.song_set_body:getWidth(), 1)
	background:add(sprites.song_set_cap_right, self.width - self.cap_width, y)

	-- The difficulty colour fades out to the right: 12% over 45% of the row, 20% over 60% when selected.
	local tint_alpha = is_selected and SELECTED_TINT_ALPHA or TINT_ALPHA
	local tint_width = self.width * (is_selected and SELECTED_TINT_LENGTH or TINT_LENGTH)
	background:setColor(diff_color[1], diff_color[2], diff_color[3], diff_color[4] * tint_alpha)
	background:add(sprites.song_set_cap_left, 0, y)
	background:add(
		sprites.song_set_tint, self.cap_width, y, 0,
		(tint_width - self.cap_width) / sprites.song_set_tint:getWidth(), 1
	)

	if is_selected then
		self.outline_y = y
		-- diff_color is reused by the next rows, copy it.
		local color = diff_color[4] > 0 and diff_color or Colors.accent
		self.outline_color = {color[1], color[2], color[3]}
	end

	self.batch:setColor(diff_color)
	self.batch:add(Resources.sprites.chart_sets_difficulty, 0, y)

	copy_color_to_cs(Colors.text)
	cs[2] = cv.title or ""
	self.title_batch:add(cs, 24, y + 4)

	copy_color_to_cs(Colors.muted)
	cs[2] = cv.artist or ""
	self.artist_batch:add(cs, 24, y + 36)

	self.batch:setColor(1, 1, 1)

	-- TODO: Dans
	if cv.difftable_chartmetas and #cv.difftable_chartmetas > 0 then -- Ranked
		self.batch:add(Resources.sprites.chart_sets_ranked, self.width - 45, y + 23)
	else
		self.batch:add(Resources.sprites.chart_sets_unranked, self.width - 45, y + 23)
	end

	if cv.lamp then
		self.batch:add(Resources.sprites.chart_sets_lamp, -80, y + 26)
	end
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
	self.background_batch:draw()
	self.batch:draw()
	Painter.snapToPixel()
	if self.outline_y then
		local color = self.outline_color
		Painter.setColorRgb(color[1], color[2], color[3])
		lg.push("transform")
		lg.translate(0, self.outline_y)
		self.outline:draw(self.width, self.item_height)
		lg.pop()
		Painter.setColorRgb(1, 1, 1)
	end
	lg.draw(self.title_batch)
	lg.draw(self.artist_batch)
end

return ChartSets
