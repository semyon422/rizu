local VirtualizedList = require("gui.VirtualizedList")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local SpriteBatch = require("gui.SpriteBatch")
local NineSliceUsage = require("gui.NineSliceUsage")
local Sounds = require("ui.Sounds")
local Color = require("ui.Color")
local Settings = require("rizu.config.Settings")
local ChartviewFormatter = require("ui.formatters.ChartviewFormatter")
local CarouselLayout = require("ui.screens.song_select_v2.CarouselLayout")
local ChartGrid = require("ui.screens.song_select_v2.ChartGrid")

---One list of sets. The selected set is unfolded into smaller rows with its charts.
---@class ui.screens.song_select_v2.ChartCarousel : gui.VirtualizedList
---@operator call: ui.screens.song_select_v2.ChartCarousel
---@field layout ui.screens.song_select_v2.CarouselLayout
---@field children_set integer? Primary index the secondary store was loaded for.
local ChartCarousel = VirtualizedList + {}

local SET_HEIGHT = 76
local CHILD_HEIGHT = 44
local GAP = 5
local CHILD_GAP = 4
local CHILD_INDENT = 48
local SCROLL_RETURN_DELAY = 2
-- Same colours as ChartSets.
local BASE_ALPHA = 0.72
local HOVER_ALPHA = 0.85
local SELECTED_ALPHA = 0.95
local TINT_ALPHA = 0.12
local TINT_LENGTH = 0.45
local SELECTED_TINT_ALPHA = 0.20
local SELECTED_TINT_LENGTH = 0.60
local DIFFICULTY_X = 18
local MODE_X = 84
local NAME_X = 152

local lg = love.graphics

---@class ui.screens.song_select_v2.ChartCarousel.Layer
---@field background gui.SpriteBatch
---@field decoration gui.SpriteBatch
---@field first love.Text
---@field second love.Text
---@field third love.Text

---Generated and packed sprites live in different atlases, so each needs its own batch.
---@param first_font love.Font
---@param second_font love.Font
---@param third_font love.Font
---@return ui.screens.song_select_v2.ChartCarousel.Layer
local function newLayer(first_font, second_font, third_font)
	return {
		background = SpriteBatch(Resources.sprites.song_set_body),
		decoration = SpriteBatch(Resources.sprites.chart_sets_difficulty),
		first = lg.newTextBatch(first_font),
		second = lg.newTextBatch(second_font),
		third = lg.newTextBatch(third_font),
	}
end

---@param layer ui.screens.song_select_v2.ChartCarousel.Layer
local function clearLayer(layer)
	layer.background:clear()
	layer.decoration:clear()
	layer.first:clear()
	layer.second:clear()
	layer.third:clear()
end

---@param layer ui.screens.song_select_v2.ChartCarousel.Layer
local function drawLayer(layer)
	layer.background:draw()
	layer.decoration:draw()
	lg.draw(layer.first)
	lg.draw(layer.second)
	lg.draw(layer.third)
end

local cs = {{1, 1, 1, 1}, ""}

---@param color gui.Color
---@param alpha number
---@param text string
---@return table
local function colored(color, alpha, text)
	local c = cs[1]
	c[1], c[2], c[3], c[4] = color[1], color[2], color[3], (color[4] or 1) * alpha
	cs[2] = text
	return cs
end

---@param charts rizu.api.Charts
---@param settings rizu.config.Config
---@param localization ui.localization.Localization
function ChartCarousel:new(charts, settings, localization)
	VirtualizedList.new(self)
	self.charts = charts
	self.settings = settings
	self.localization = localization
	self.formatter = ChartviewFormatter(nil, settings)
	self.layout = CarouselLayout(SET_HEIGHT, GAP, CHILD_HEIGHT, CHILD_GAP)
	self.layout.CLOSE_HALF_LIFE = math.log(2) / (self.SCROLL_DECAY * 1000)
	self.item_height = SET_HEIGHT
	self.gap = GAP
	self.handles_keyboard_input = true
	self.scroll_return_elapsed = 0
	self.focus_child = false
	self.centering = false
	self.scroll_return_pending = false
	self.set_layer = newLayer(
		Resources.getFont("cjk_bold", 24), Resources.getFont("cjk_regular", 24), Resources.getFont("cjk_regular", 24))
	self.child_layer = newLayer(
		Resources.getFont("bold", 22), Resources.getFont("regular", 20), Resources.getFont("cjk_regular", 20))
	self.outline = NineSliceUsage(Resources.nine_slices.song_set_outline)
	self.diff_color = {0, 0, 0, 0}

	if charts:getChartCount() > 0 then
		self.children_set = charts:getSelectedSetIndex()
	end
	charts:on("charts_changed", function()
		self.children_set = charts:getSelectedSetIndex()
	end)
	charts:on("sets_changed", function()
		self.layout:reset()
		self.children_set = nil
	end)

	self.visit_set = function(index, y) self:addSet(index, y) end
	self.visit_child = function(group, j, y, fade) self:addChild(group, j, y, fade) end
end

function ChartCarousel:load() end

function ChartCarousel:onLayoutChanged()
	self.cap_width = Resources.sprites.song_set_cap_left:getWidth()
	self.child_cap_width = Resources.sprites.song_chart_cap_left:getWidth()
	self:scrollToFocus(true)
end

---@return integer count
function ChartCarousel:getItemCount()
	return self.charts:getSetCount()
end

---The taller of the current and final layout. Only the final one would clamp the camera
---when a big set above the selection is still closing, and only the current one would clamp
---the target while a set is still opening.
---@return number size
function ChartCarousel:getScrollContentSize()
	local layout = self.layout
	return math.max(layout:getContentHeight(), layout:getContentHeight(true))
end

---Scroll position that centres the focused row where it is right now, not where it will end up.
---Aiming at the final layout makes the camera move the wrong way while rows above are still closing.
---@private
---@return number
function ChartCarousel:getFocusScroll()
	local layout = self.layout
	local charts = self.charts
	local center
	local group = self:getOpenGroup()
	local child = charts:getSelectedChartIndex()
	if self.focus_child and group and child >= 1 and child <= group.count then
		center = layout:getChildY(group, child) + CHILD_HEIGHT / 2
	else
		center = layout:getSetY(charts:getSelectedSetIndex()) + SET_HEIGHT / 2
	end
	return center + GAP / 2 - self.height / 2
end

---Centres the selection and keeps following it until the camera arrives.
---@param immediate boolean?
function ChartCarousel:scrollToFocus(immediate)
	self.centering = true
	self.scroll_return_pending = false
	self:scrollTo(self:getFocusScroll(), immediate)
end

---@private
---@return ui.screens.song_select_v2.CarouselLayout.Group?
function ChartCarousel:getOpenGroup()
	local selected = self.charts:getSelectedSetIndex()
	for _, g in ipairs(self.layout.groups) do
		if g.index == selected and g.target == 1 then
			return g
		end
	end
end

---@private
function ChartCarousel:markScrollActivity()
	self.scroll_return_elapsed = 0
	self.scroll_return_pending = true
end

function ChartCarousel:update(dt)
	VirtualizedList.update(self, dt)

	local charts = self.charts
	local layout = self.layout
	local selected = charts:getSelectedSetIndex()
	local children_count = charts:getChartCount()

	layout:setSetCount(charts:getSetCount())
	-- Where the selected set was drawn last frame, even if it was not the selected one then.
	local prev_set_y = layout:getSetY(selected)
	if self.children_set == selected and children_count > 0 then
		layout:expand(selected, children_count)
	else
		layout:collapse()
	end
	layout:update(dt)

	local group = self:getOpenGroup()
	local child = group and charts:getSelectedChartIndex() or 0
	-- Taken from osu!lazer (Carousel.cs): keep the selected set still on screen while rows above it open or close.
	local set_y = layout:getSetY(selected)
	-- Also on the frame the selection changes: the set above that starts closing would otherwise
	-- pull the newly clicked set off screen in one frame, before the camera starts following it.
	if self.last_selected then
		local shift = set_y - prev_set_y
		self.scroll_current = self.scroll_current + shift
	end
	if selected ~= self.last_selected then
		-- The chart picked inside a new set is not worth a second camera move.
		self.focus_child = false
		self:scrollToFocus()
	elseif group and self.last_child ~= 0 and child ~= self.last_child then
		self.focus_child = true
		self:scrollToFocus()
	end
	self.last_selected, self.last_child = selected, child
	if self.centering then
		self:scrollTo(self:getFocusScroll())
		if self.scroll_current == self.scroll_target and not layout:isAnimating() then
			self.centering = false
		end
	end

	local scroll = self:getVisualScrollPosition()
	local last_kind, last_a, last_b = self.hover_kind, self.hover_set, self.hover_child
	self.hover_kind, self.hover_set, self.hover_child = nil, nil, nil
	if self.mouse_over then
		self:markScrollActivity()
		local _, my = self.world_transform:inverseTransformPoint(love.mouse.getPosition())
		if my >= 0 and my < self.height then
			self.hover_kind, self.hover_set, self.hover_child = layout:locate(my + scroll - GAP / 2)
		end
	end
	if last_kind ~= self.hover_kind or last_a ~= self.hover_set or last_b ~= self.hover_child then
		Sounds.play("hover")
	end

	if self.mouse_over and love.mouse.isDown(2) then
		local _, mouse_y = self.world_transform:inverseTransformPoint(love.mouse.getPosition())
		local scroll_normal = math.min(math.max(mouse_y / self.height, 0), 1)
		self.centering = false
		self:stopScrollMotion()
		self:scrollTo(self:getMaxScroll() * scroll_normal)
	elseif self.scroll_return_pending and not self.drag_active then
		self.scroll_return_elapsed = self.scroll_return_elapsed + dt
		if self.scroll_return_elapsed >= SCROLL_RETURN_DELAY then
			self.scroll_return_pending = false
			self:stopScrollMotion()
			self:scrollToFocus()
		end
	end

	clearLayer(self.set_layer)
	clearLayer(self.child_layer)
	self.outline_set_y, self.outline_child_y, self.outline_child_alpha = nil, nil, nil
	scroll = self:getVisualScrollPosition()
	self.draw_scroll = scroll
	layout:visit(scroll - GAP, scroll + self.height, self.visit_set, self.visit_child)
end

---@private
---@param index integer
---@param content_y number
function ChartCarousel:addSet(index, content_y)
	local cv = self.charts:getSet(index)
	if not cv then return end

	local y = content_y - self.draw_scroll + GAP / 2
	local is_selected = index == self.charts:getSelectedSetIndex()
	local is_hovered = self.hover_kind == "set" and self.hover_set == index
	local diff_column = self.settings:getChoice(Settings.keys.select.diff_column)
	local diff = cv[diff_column] ---@type number?
	local diff_color = self.diff_color
	if diff then
		Color.diffToColor(diff_column, diff, diff_color)
		diff_color[4] = 1
	else
		diff_color[4] = 0
	end

	local sprites = Resources.sprites
	local layer = self.set_layer
	local background = layer.background
	local base, alpha = Colors.panel, BASE_ALPHA
	if is_selected then
		base, alpha = Colors.surface, SELECTED_ALPHA
	elseif is_hovered then
		base, alpha = Colors.surface_raised, HOVER_ALPHA
	end
	background:setColor(base[1], base[2], base[3], alpha)
	background:add(sprites.song_set_cap_left, 0, y)
	background:add(sprites.song_set_body, self.cap_width, y, 0,
		(self.width - self.cap_width * 2) / sprites.song_set_body:getWidth(), 1)
	background:add(sprites.song_set_cap_right, self.width - self.cap_width, y)

	-- The difficulty colour fades out to the right.
	local tint_alpha = is_selected and SELECTED_TINT_ALPHA or TINT_ALPHA
	local tint_width = self.width * (is_selected and SELECTED_TINT_LENGTH or TINT_LENGTH)
	background:setColor(diff_color[1], diff_color[2], diff_color[3], diff_color[4] * tint_alpha)
	background:add(sprites.song_set_cap_left, 0, y)
	background:add(sprites.song_set_tint, self.cap_width, y, 0,
		(tint_width - self.cap_width) / sprites.song_set_tint:getWidth(), 1)

	if is_selected then
		self.outline_set_y = y
		local color = diff_color[4] > 0 and diff_color or Colors.accent
		self.outline_set_color = {color[1], color[2], color[3]}
	end

	local decoration = layer.decoration
	decoration:setColor(diff_color)
	decoration:add(sprites.chart_sets_difficulty, 0, y)
	decoration:setColor(1, 1, 1)
	self.formatter:setChartview(cv)
	if not cv.loaded then
		-- Nothing to say about the row yet.
	elseif self.formatter:isDan() then
		decoration:add(sprites.chart_sets_dan, self.width - 45, y + 23)
	elseif cv.difftable_chartmetas and #cv.difftable_chartmetas > 0 then -- Ranked
		decoration:add(sprites.chart_sets_ranked, self.width - 45, y + 23)
	else
		decoration:add(sprites.chart_sets_unranked, self.width - 45, y + 23)
	end

	if cv.lamp then
		decoration:add(sprites.chart_sets_lamp, self.width - 45 - sprites.chart_sets_lamp:getWidth() - 8, y + 23)
	end

	layer.first:add(colored(Colors.text, 1, cv.title or ""), 24, y + 4)
	layer.second:add(colored(Colors.muted, 1, cv.artist or ""), 24, y + 36)
end

---@private
---@param group ui.screens.song_select_v2.CarouselLayout.Group
---@param j integer
---@param content_y number
---@param fade number
function ChartCarousel:addChild(group, j, content_y, fade)
	local cv
	local is_open = group.target == 1
	if is_open then
		cv = self.charts:getChart(j)
		group.items[j] = cv
	else
		cv = group.items[j]
	end
	if not cv then return end

	local y = content_y - self.draw_scroll + GAP / 2
	local is_selected = is_open and j == self.charts:getSelectedChartIndex()
	local is_hovered = self.hover_kind == "child" and self.hover_set == group.index and self.hover_child == j
	local formatter = self.formatter
	formatter:setChartview(cv)
	local difficulty = formatter:getDifficulty()
	local mode = (formatter:getMode():gsub(" %(EXPERIMENTAL%)$", ""))
	local name = formatter:getName() or self.localization:get("song_select.unknown_difficulty")

	local sprites = Resources.sprites
	local layer = self.child_layer
	local background = layer.background
	local x = CHILD_INDENT
	local width = self.width - CHILD_INDENT
	local cap = self.child_cap_width
	local base, alpha = Colors.panel, BASE_ALPHA
	if is_selected then
		base, alpha = Colors.surface, SELECTED_ALPHA
	elseif is_hovered then
		base, alpha = Colors.surface_raised, HOVER_ALPHA
	end
	background:setColor(base[1], base[2], base[3], alpha * fade)
	background:add(sprites.song_chart_cap_left, x, y)
	background:add(sprites.song_chart_body, x + cap, y, 0, (width - cap * 2) / sprites.song_chart_body:getWidth(), 1)
	background:add(sprites.song_chart_cap_right, x + width - cap, y)

	local color = difficulty.color
	local tint_alpha = is_selected and SELECTED_TINT_ALPHA or TINT_ALPHA
	local tint_width = width * (is_selected and SELECTED_TINT_LENGTH or TINT_LENGTH)
	background:setColor(color[1], color[2], color[3], tint_alpha * fade)
	background:add(sprites.song_chart_cap_left, x, y)
	background:add(sprites.song_set_tint, x + cap, y, 0,
		(tint_width - cap) / sprites.song_set_tint:getWidth(), CHILD_HEIGHT / sprites.song_set_tint:getHeight())

	if is_selected then
		self.outline_child_y = y
		self.outline_child_alpha = fade
		self.outline_child_color = {color[1], color[2], color[3]}
	end

	local first_font, second_font, third_font = layer.first:getFont(), layer.second:getFont(), layer.third:getFont()
	local text_y = y + (CHILD_HEIGHT - second_font:getHeight()) / 2
	layer.first:add(colored(color, fade, difficulty.value), x + DIFFICULTY_X, y + (CHILD_HEIGHT - first_font:getHeight()) / 2)
	layer.second:add(colored(Colors.muted, fade, ChartGrid.fitText(second_font, mode, NAME_X - MODE_X - 8)),
		x + MODE_X, text_y)
	layer.third:add(colored(Colors.text, fade, ChartGrid.fitText(third_font, name, width - NAME_X - 16)),
		x + NAME_X, y + (CHILD_HEIGHT - third_font:getHeight()) / 2)
end

---@param e gui.ScrollEvent
---@return boolean handled
function ChartCarousel:onScroll(e)
	self.centering = false
	self:markScrollActivity()
	return VirtualizedList.onScroll(self, e)
end

---@param e gui.DragStartEvent
---@return boolean? handled
function ChartCarousel:onDragStart(e)
	local handled = VirtualizedList.onDragStart(self, e)
	if handled then
		self.centering = false
		self:markScrollActivity()
	end
	return handled
end

---@param e gui.DragEvent
---@return boolean? handled
function ChartCarousel:onDrag(e)
	local handled = VirtualizedList.onDrag(self, e)
	if handled then
		self:markScrollActivity()
	end
	return handled
end

function ChartCarousel:onKeyDown(e)
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

function ChartCarousel:onMouseClick(e)
	if e.button ~= 1 or not self.hover_kind then
		return
	end
	if self.hover_kind == "set" then
		self.charts:selectSet(self.hover_set)
		Sounds.play("set_changed")
	else
		self.charts:selectChart(self.hover_child)
		Sounds.play("chart_changed")
	end
	return true
end

---@param x number
---@param y number
---@param width number
---@param height number
---@param color number[]
---@param alpha number
function ChartCarousel:drawOutline(x, y, width, height, color, alpha)
	Painter.setColorRgb(color[1], color[2], color[3], alpha)
	lg.push("transform")
	lg.translate(x, y)
	self.outline:draw(width, height)
	lg.pop()
	Painter.setColorRgb(1, 1, 1)
end

function ChartCarousel:draw()
	-- Chart rows go first so the set row they unfold from covers them.
	drawLayer(self.child_layer)
	Painter.snapToPixel()
	if self.outline_child_y then
		self:drawOutline(CHILD_INDENT, self.outline_child_y, self.width - CHILD_INDENT, CHILD_HEIGHT,
			self.outline_child_color, self.outline_child_alpha)
	end
	drawLayer(self.set_layer)
	if self.outline_set_y then
		self:drawOutline(0, self.outline_set_y, self.width, SET_HEIGHT, self.outline_set_color, 1)
	end
end

return ChartCarousel
