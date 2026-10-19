local VirtualizedList = require("gui.VirtualizedList")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local SpriteBatch = require("gui.SpriteBatch")
local NineSliceUsage = require("gui.NineSliceUsage")
local Sounds = require("ui.Sounds")
local ChartviewFormatter = require("ui.formatters.ChartviewFormatter")
local ChartCarousel = require("ui.screens.song_select_v2.ChartCarousel")

---The list for ungrouped sorts, where every set row is a single chart.
---@class ui.screens.song_select_v2.ChartList : gui.VirtualizedList
---@operator call: ui.screens.song_select_v2.ChartList
local ChartList = VirtualizedList + {}

local ITEM_HEIGHT = 76
local SCROLL_RETURN_DELAY = 2
-- Same colours as ChartCarousel.
local BASE_ALPHA = 0.72
local HOVER_ALPHA = 0.85
local SELECTED_ALPHA = 0.95
local TINT_ALPHA = 0.12
local TINT_LENGTH = 0.45
local SELECTED_TINT_ALPHA = 0.20
local SELECTED_TINT_LENGTH = 0.60
local CAPSULE_X = 18
local MODE_X = CAPSULE_X + 76
local MODE_WIDTH = 70
local TITLE_X = MODE_X + MODE_WIDTH
local ARTIST_GAP = 12
local BADGE_RIGHT = 45
local TOP_Y = 4
local BOTTOM_Y = 40
-- Dark enough for the coloured difficulty to read over the tint.
local CAPSULE_ALPHA = 0.55

local lg = love.graphics

local cs = {{1, 1, 1, 1}, ""}

---@param color gui.Color
---@param text string
---@return table
local function colored(color, text)
	local c = cs[1]
	c[1], c[2], c[3], c[4] = color[1], color[2], color[3], color[4] or 1
	cs[2] = text
	return cs
end

---@param charts rizu.api.Charts
---@param settings rizu.config.Config
---@param localization ui.localization.Localization
function ChartList:new(charts, settings, localization)
	VirtualizedList.new(self)
	self.charts = charts
	self.localization = localization
	self.gap = 5
	self.item_height = ITEM_HEIGHT
	self.hover_index = nil
	self.scroll_return_elapsed = 0
	self.scroll_return_pending = false
	self.handles_keyboard_input = true
	-- Generated and packed sprites live in different atlases, so each needs its own batch.
	self.background_batch = SpriteBatch(Resources.sprites.song_set_body)
	self.batch = SpriteBatch(Resources.sprites.chart_sets_difficulty)
	self.formatter = ChartviewFormatter(nil, settings)
	self.outline = NineSliceUsage(Resources.nine_slices.song_set_outline)
	self.difficulty_batch = lg.newTextBatch(Resources.getFont("cjk_bold", 26))
	self.mode_batch = lg.newTextBatch(Resources.getFont("cjk_regular", 20))
	self.title_batch = lg.newTextBatch(Resources.getFont("cjk_bold", 24))
	self.artist_batch = lg.newTextBatch(Resources.getFont("cjk_regular", 24))
	self.name_batch = lg.newTextBatch(Resources.getFont("cjk_regular", 20))
end

function ChartList:load() end

function ChartList:onLayoutChanged(old_x, old_y, old_width, old_height)
	self.cap_width = Resources.sprites.song_set_cap_left:getWidth()
	self.mid_width = self.width - self.cap_width * 2
	self:scrollToIndex(self.charts:getSelectedSetIndex(), true)
end

---@return integer count
function ChartList:getItemCount()
	return self.charts:getSetCount()
end

---@private
function ChartList:markScrollActivity()
	self.scroll_return_elapsed = 0
	self.scroll_return_pending = true
end

function ChartList:update(dt)
	VirtualizedList.update(self, dt)

	local charts = self.charts
	local item_count = charts:getSetCount()
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
	self.difficulty_batch:clear()
	self.mode_batch:clear()
	self.title_batch:clear()
	self.artist_batch:clear()
	self.name_batch:clear()

	local selected_index = self.charts:getSelectedSetIndex()
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
		local cv = charts:getSet(i)
		if cv then
			local y = (i - 1) * row_step - scroll + self.gap / 2
			self:drawItem(cv, y, i == selected_index, i == self.hover_index)
		end
	end
end

---@param cv rizu.api.Chart
---@param y number
---@param is_selected boolean
---@param is_hovered boolean
function ChartList:drawItem(cv, y, is_selected, is_hovered)
	local formatter = self.formatter
	formatter:setChartview(cv)
	local difficulty = formatter:getDifficulty()
	local color = difficulty.color

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

	-- The difficulty colour fades out to the right.
	local tint_alpha = is_selected and SELECTED_TINT_ALPHA or TINT_ALPHA
	local tint_width = self.width * (is_selected and SELECTED_TINT_LENGTH or TINT_LENGTH)
	background:setColor(color[1], color[2], color[3], tint_alpha)
	background:add(sprites.song_set_cap_left, 0, y)
	background:add(
		sprites.song_set_tint, self.cap_width, y, 0,
		(tint_width - self.cap_width) / sprites.song_set_tint:getWidth(), 1
	)

	local capsule = sprites.song_chart_difficulty_capsule
	local capsule_width, capsule_height = capsule:getDimensions()
	local capsule_y = y + (ITEM_HEIGHT - capsule_height) / 2 + 3
	local bg = Colors.background
	background:setColor(bg[1], bg[2], bg[3], CAPSULE_ALPHA)
	background:add(capsule, CAPSULE_X, capsule_y)

	if is_selected then
		self.outline_y = y
		self.outline_color = color
	end

	local batch = self.batch
	batch:setColor(color)
	batch:add(sprites.chart_sets_difficulty, 0, y)
	batch:setColor(1, 1, 1)

	local text_right = self.width - BADGE_RIGHT - 16
	local uncached = ChartCarousel.isUncached(cv)
	if not cv.loaded or uncached then
		-- Nothing to say about the row yet.
	elseif formatter:isDan() then
		batch:add(sprites.chart_sets_dan, self.width - BADGE_RIGHT, y + 23)
	elseif cv.difftable_chartmetas and #cv.difftable_chartmetas > 0 then -- Ranked
		batch:add(sprites.chart_sets_ranked, self.width - BADGE_RIGHT, y + 23)
	else
		batch:add(sprites.chart_sets_unranked, self.width - BADGE_RIGHT, y + 23)
	end
	if cv.lamp then
		local lamp_x = self.width - BADGE_RIGHT - sprites.chart_sets_lamp:getWidth() - 8
		batch:add(sprites.chart_sets_lamp, lamp_x, y + 23)
		text_right = lamp_x - 16
	end

	local fitText = ChartCarousel.fitText
	if not cv.loaded then
		self.title_batch:add(colored(Colors.muted, self.localization:get("song_select.loading")), TITLE_X, y + TOP_Y)
		return
	elseif uncached then
		local text_width = text_right - TITLE_X
		self.title_batch:add(colored(Colors.text, fitText(self.title_batch:getFont(), cv.chartfile_name or "", text_width)),
			TITLE_X, y + TOP_Y)
		self.name_batch:add(colored(Colors.accent, fitText(self.name_batch:getFont(),
			self.localization:get("song_select.uncached"), text_width)), TITLE_X, y + BOTTOM_Y)
		return
	end
	local mode = (formatter:getMode():gsub(" %(EXPERIMENTAL%)$", ""))
	local difficulty_font = self.difficulty_batch:getFont()
	local value = fitText(difficulty_font, difficulty.value, capsule_width - 12)
	self.difficulty_batch:add(colored(color, value),
		math.floor(CAPSULE_X + (capsule_width - difficulty_font:getWidth(value)) / 2),
		y + (ITEM_HEIGHT - difficulty_font:getHeight()) / 2 - 1)
	local mode_font = self.mode_batch:getFont()
	mode = fitText(mode_font, mode, MODE_WIDTH - 12)
	self.mode_batch:add(colored(Colors.muted, mode),
		math.floor(MODE_X + (MODE_WIDTH - mode_font:getWidth(mode)) / 2),
		y + (ITEM_HEIGHT - mode_font:getHeight()) / 2)

	local text_width = text_right - TITLE_X
	local title_font = self.title_batch:getFont()
	local title = fitText(title_font, formatter:getTitle(), text_width)
	self.title_batch:add(colored(Colors.text, title), TITLE_X, y + TOP_Y)
	local artist_x = TITLE_X + title_font:getWidth(title) + ARTIST_GAP
	local artist_font = self.artist_batch:getFont()
	-- Not even an ellipsis fits when the title takes the whole row.
	if text_right - artist_x > artist_font:getWidth("…") then
		local artist = fitText(artist_font, formatter:getArtist(), text_right - artist_x)
		self.artist_batch:add(colored(Colors.muted, artist), artist_x, y + TOP_Y)
	end

	local name = formatter:getName() or self.localization:get("song_select.unknown_difficulty")
	self.name_batch:add(colored(Colors.text, fitText(self.name_batch:getFont(), name, text_width)),
		TITLE_X, y + BOTTOM_Y)
end

---@param e gui.ScrollEvent
---@return boolean handled
function ChartList:onScroll(e)
	self:markScrollActivity()
	return VirtualizedList.onScroll(self, e)
end

---@param e gui.DragStartEvent
---@return boolean? handled
function ChartList:onDragStart(e)
	local handled = VirtualizedList.onDragStart(self, e)
	if handled then
		self:markScrollActivity()
	end
	return handled
end

---@param e gui.DragEvent
---@return boolean? handled
function ChartList:onDrag(e)
	local handled = VirtualizedList.onDrag(self, e)
	if handled then
		self:markScrollActivity()
	end
	return handled
end

function ChartList:onKeyDown(e)
	if e.key == "j" then
		self.charts:moveSet(1)
		Sounds.play("set_changed")
		return true
	elseif e.key == "k" then
		self.charts:moveSet(-1)
		Sounds.play("set_changed")
		return true
	end
end

---@param index integer
---@param immediate boolean?
function ChartList:scrollToIndex(index, immediate)
	local row_step = self.item_height + self.gap
	local target = (index - 1) * row_step - (self.height / 2) + (row_step / 2)
	self:scrollTo(target, immediate)
end

function ChartList:onMouseClick(e)
	if e.button == 1 and self.hover_index then
		self.charts:selectSet(self.hover_index)
		self:scrollToIndex(self.hover_index)
		Sounds.play("set_changed")
		return true
	end
end

function ChartList:draw()
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
	lg.draw(self.difficulty_batch)
	lg.draw(self.mode_batch)
	lg.draw(self.title_batch)
	lg.draw(self.artist_batch)
	lg.draw(self.name_batch)
end

return ChartList
