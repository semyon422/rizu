local View = require("gui.View")
local Resources = require("yi.Resources")
local Settings = require("rizu.config.schemas.Settings")
local Colors = require("yi.Colors")
local Color = require("yi.Color")
local Painter = require("yi.Painter")
local SpringValue = require("gui.anim.SpringValue")

---@class yi.views.select.CombinedList : gui.View
---@operator call: yi.views.select.CombinedList
local CombinedList = View + {}

---@param chart_selector rizu.select.ChartSelector
---@param config rizu.config.Config
function CombinedList:new(chart_selector, config)
	View.new(self)
	self.scroll_spring = SpringValue({stiffness = 480, damping = 48})
	self.handles_mouse_input = true
	self.chart_selector = chart_selector
	self.config = config
	self.sdf_batch = love.graphics.newTextBatch(Resources.getSdfFont()) ---@type love.Text
	self.text_batch = love.graphics.newTextBatch(Resources.getFont("regular", 24)) ---@type love.Text
	self.sprite_batch = love.graphics.newSpriteBatch(Resources.atlas)
	self.set_y_positions = {}
	self.chart_y_positions = {}
	self.last_sel_set_index = nil
	self.items_cleared = false
	self.charts_alpha_spring = SpringValue({stiffness = 300, damping = 30})
	self.charts_alpha_spring:snap(0.0)
	self:setWidth(500)
end

function CombinedList:load()
	self.set_height = Painter.getQuadHeight(Resources.quads.set_panel)
	self.chart_height = Painter.getQuadHeight(Resources.quads.chart_panel)
	self.gap = 8
	self.diff_column = self.config:getString(Settings.select.display.diff_column)
	View.load(self)
	self:snapToSelected()
end

---@param i integer
---@param sel_set_index integer
---@param total_chart_height number
---@return number
function CombinedList:getSetY(i, sel_set_index, total_chart_height)
	if i <= sel_set_index then
		return (i - 1) * (self.set_height + self.gap)
	else
		return (i - 1) * (self.set_height + self.gap) + total_chart_height
	end
end

---@param c integer
---@param sel_set_index integer
---@return number
function CombinedList:getChartY(c, sel_set_index)
	return (sel_set_index - 1) * (self.set_height + self.gap) + self.set_height + self.gap + (c - 1) * (self.chart_height + self.gap)
end

---@param sel_set_index integer
---@param sel_chart_index integer
---@return number
function CombinedList:getScrollTarget(sel_set_index, sel_chart_index)
	local focus_y = self:getChartY(sel_chart_index, sel_set_index)
	local focus_h = self.chart_height
	return focus_y - ((self.height and self.height > 0) and (self.height - focus_h) / 2 or (540 - focus_h / 2))
end

function CombinedList:snapToSelected()
	if self.items_cleared then return end

	local sel_set_index = self:getPrimarySelectedIndex()
	local sel_chart_index = self:getSecondarySelectedIndex()

	if not sel_set_index or not sel_chart_index then
		return
	end

	local num_sets = self.chart_selector.stores[1]:count()
	local num_charts = self.chart_selector.stores[2]:count()
	local total_chart_height = num_charts * (self.chart_height + self.gap)

	self.set_y_positions = {}
	for i = 1, num_sets do
		self.set_y_positions[i] = self:getSetY(i, sel_set_index, total_chart_height)
	end

	self.chart_y_positions = {}
	for c = 1, num_charts do
		self.chart_y_positions[c] = self:getChartY(c, sel_set_index)
	end
	self.last_sel_set_index = sel_set_index
	self.charts_alpha_spring:snap(1.0)

	self.scroll_spring:snap(self:getScrollTarget(sel_set_index, sel_chart_index))
end

function CombinedList:clearItems()
	self.set_y_positions = {}
	self.chart_y_positions = {}
	self.last_sel_set_index = nil
	self.charts_alpha_spring:snap(0.0)
	self:resetBatches()
	self.items_cleared = true
end

function CombinedList:reloadItems()
	self.items_cleared = false
	self:snapToSelected()
end

---@return integer
function CombinedList:getPrimarySelectedIndex()
	return self.chart_selector.state:getPrimary().index
end

---@return integer
function CombinedList:getSecondarySelectedIndex()
	return self.chart_selector.state:getSecondary().index
end

---@param index integer
---@return rizu.library.LocatedChartview?
function CombinedList:getPrimaryItem(index)
	return self.chart_selector.stores[1]:get(index)
end

---@param index integer
---@return rizu.library.LocatedChartview?
function CombinedList:getSecondaryItem(index)
	return self.chart_selector.stores[2]:get(index)
end

function CombinedList:onScroll(e)
	if e.direction_y > 0 then
		self.chart_selector:scrollLevel(1, -1)
	elseif e.direction_y < 0 then
		self.chart_selector:scrollLevel(1, 1)
	end
end

function CombinedList:resetBatches()
	self.text_batch:clear()
	self.sprite_batch:clear()
	self.sdf_batch:clear()
end

function CombinedList:addSetToBatch(item, y, is_selected, index)
	local alpha = is_selected and 1.0 or 0.5
	local center_y = (self.height and self.height > 0) and (self.height / 2) or 540
	local dist = (y + self.set_height / 2) - center_y
	local norm_dist = dist / center_y
	local shift_x = (norm_dist * norm_dist) * 50

	local slide_offset = is_selected and -50 or 0

	local px = self.width - 477 + shift_x + slide_offset
	local py = y

	self.sprite_batch:setColor(alpha, alpha, alpha, 1)
	self.sprite_batch:add(Resources.quads.set_panel, px, py)

	local tx = px + 24
	local ty_title = py + 18
	local ty_artist = py + 50

	local shadow_color = {0, 0, 0, 0.5 * alpha}
	local title_color = {Colors.text[1], Colors.text[2], Colors.text[3], alpha}
	local artist_color = {Colors.text_muted[1], Colors.text_muted[2], Colors.text_muted[3], alpha}

	local title_text = item.title or "Unknown"
	local artist_text = item.artist or "Unknown"

	-- Draw title
	self.text_batch:add({shadow_color, title_text}, tx + 2, ty_title + 2)
	self.text_batch:add({title_color, title_text}, tx, ty_title)

	-- Draw artist
	self.text_batch:add({shadow_color, artist_text}, tx + 2, ty_artist + 2)
	self.text_batch:add({artist_color, artist_text}, tx, ty_artist)
end

function CombinedList:addChartToBatch(item, y, is_selected, index, alpha_factor)
	local base_alpha = is_selected and 1.0 or 0.9
	local alpha = base_alpha * (alpha_factor or 1.0)
	local center_y = (self.height and self.height > 0) and (self.height / 2) or 540
	local dist = (y + self.chart_height / 2) - center_y
	local norm_dist = dist / center_y
	local shift_x = (norm_dist * norm_dist) * 50

	local slide_offset = is_selected and -50 or 0

	local px = self.width - 437 + shift_x + slide_offset
	local py = y

	local color = {1, 1, 1, 1}
	local diff_val = 0
	if self.diff_column == "enps_diff" then
		diff_val = item.enps_diff or 0
		Color.enpsToColor(diff_val, color)
	elseif self.diff_column == "msd_diff" then
		diff_val = item.msd_diff or 0
		Color.msdToColor(diff_val, color)
	elseif self.diff_column == "osu_diff" then
		diff_val = item.osu_diff or 0
		Color.osuToColor(diff_val, color)
	end

	color[4] = alpha
	self.sprite_batch:setColor(color[1] * 0.3, color[2] * 0.3, color[3] * 0.3, color[4])
	self.sprite_batch:add(Resources.quads.chart_panel, px, py)

	local text_y = py + 12
	local shadow_color = {0, 0, 0, 0.5 * alpha}

	-- Draw difficulty rating
	local diff_text = string.format("%.1f", diff_val)
	local diff_color = {color[1], color[2], color[3], alpha}
	self.sdf_batch:add({diff_color, diff_text}, px + 15, py + 8, 0, Painter.getFontScaleFor(32))

	-- Draw difficulty name
	local name_text = item.name or "Unknown"
	local name_color = {Colors.text[1], Colors.text[2], Colors.text[3], alpha}
	self.text_batch:add({shadow_color, name_text}, px + 100 + 2, text_y + 2)
	self.text_batch:add({name_color, name_text}, px + 100, text_y)

	-- Draw input mode
	if item.inputmode then
		local input_text = item.inputmode:gsub("key", "K"):gsub("scratch", "S")
		local input_color = {Colors.text[1], Colors.text[2], Colors.text[3], alpha}
		self.text_batch:addf({shadow_color, input_text}, 100, "right", px + 317 + 2, text_y + 2)
		self.text_batch:addf({input_color, input_text}, 100, "right", px + 317, text_y)
	end
end

function CombinedList:update(dt)
	if self.items_cleared then
		self:resetBatches()
		return
	end

	local sel_set_index = self:getPrimarySelectedIndex()
	if not sel_set_index then return end

	local num_sets = self.chart_selector.stores[1]:count()
	if #self.set_y_positions ~= num_sets then
		self.set_y_positions = {}
	end

	local num_charts = self.chart_selector.stores[2]:count()
	if self.last_sel_set_index ~= sel_set_index or #self.chart_y_positions ~= num_charts then
		self.chart_y_positions = {}
		self.last_sel_set_index = sel_set_index
		self.charts_alpha_spring:snap(0.0)
	end

	local total_chart_height = num_charts * (self.chart_height + self.gap)
	local sel_chart_index = self:getSecondarySelectedIndex()

	-- Update animated positions
	local decay = math.pow(0.875, dt / (1 / 60))
	for i = 1, num_sets do
		local target_y = self:getSetY(i, sel_set_index, total_chart_height)
		self.set_y_positions[i] = target_y - (target_y - (self.set_y_positions[i] or target_y)) * decay
	end

	local parent_y = self.set_y_positions[sel_set_index] or ((sel_set_index - 1) * (self.set_height + self.gap))
	for c = 1, num_charts do
		local target_y = self:getChartY(c, sel_set_index)
		self.chart_y_positions[c] = target_y - (target_y - (self.chart_y_positions[c] or parent_y)) * decay
	end

	-- Focus camera on target
	local scroll_target = self:getScrollTarget(sel_set_index, sel_chart_index)
	self.scroll_spring:set(scroll_target)
	self.scroll_spring:update(dt)

	self.charts_alpha_spring:set(1.0)
	self.charts_alpha_spring:update(dt)

	self:rebuildBatches(sel_set_index, sel_chart_index, num_charts, total_chart_height)
end

---@param sel_set_index integer
---@param sel_chart_index integer
---@param num_charts integer
---@param total_chart_height number
function CombinedList:rebuildBatches(sel_set_index, sel_chart_index, num_charts, total_chart_height)
	local scroll_y = self.scroll_spring:get()
	self:resetBatches()

	local num_sets = self.chart_selector.stores[1]:count()
	local step = self.set_height + self.gap
	local view_height = (self.height and self.height > 0) and self.height or 1080

	-- Draw visible sets before/including the selected set
	local min_i_1 = math.max(1, math.floor((scroll_y - self.set_height) / step) - 2)
	local max_i_1 = math.min(sel_set_index, math.ceil((scroll_y + view_height) / step) + 2)

	for i = min_i_1, max_i_1 do
		local set_y = self.set_y_positions[i] or self:getSetY(i, sel_set_index, total_chart_height)
		local screen_y = set_y - scroll_y

		if screen_y + self.set_height >= 0 and screen_y <= view_height then
			local set_item = self:getPrimaryItem(i)
			if set_item then
				self:addSetToBatch(set_item, screen_y, i == sel_set_index, i)
			end
		end
	end

	-- Draw visible charts of the selected set
	if num_charts > 0 then
		local alpha_factor = self.charts_alpha_spring:get()
		for c = 1, num_charts do
			local chart_y = self.chart_y_positions[c] or self:getChartY(c, sel_set_index)
			local chart_screen_y = chart_y - scroll_y

			if chart_screen_y + self.chart_height >= 0 and chart_screen_y <= view_height then
				local chart_item = self:getSecondaryItem(c)
				if chart_item then
					local is_chart_selected = (c == sel_chart_index)
					self:addChartToBatch(chart_item, chart_screen_y, is_chart_selected, c, alpha_factor)
				end
			end
		end
	end

	-- Draw visible sets after the selected set
	local min_i_2 = math.max(sel_set_index + 1, math.floor((scroll_y - self.set_height - total_chart_height) / step) - 2)
	local max_i_2 = math.min(num_sets, math.ceil((scroll_y + view_height - total_chart_height) / step) + 3)

	for i = min_i_2, max_i_2 do
		local set_y = self.set_y_positions[i] or self:getSetY(i, sel_set_index, total_chart_height)
		local screen_y = set_y - scroll_y

		if screen_y + self.set_height >= 0 and screen_y <= view_height then
			local set_item = self:getPrimaryItem(i)
			if set_item then
				self:addSetToBatch(set_item, screen_y, false, i)
			end
		end
	end
end

function CombinedList:draw()
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(self.sprite_batch)
	love.graphics.draw(self.text_batch)

	Painter.setFontOutline(0.12)
	Painter.setFontThickness(0.45)
	Painter.setFontOutlineColor(Colors.text_shadow)
	Painter.beginTextDrawing()
	love.graphics.draw(self.sdf_batch)
	Painter.endTextDrawing()
end

return CombinedList
