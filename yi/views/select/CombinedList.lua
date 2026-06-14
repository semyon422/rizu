local BaseList = require("yi.views.select.BaseList")
local Resources = require("yi.Resources")
local Settings = require("rizu.config.schemas.Settings")
local Colors = require("yi.Colors")
local Color = require("yi.Color")
local Painter = require("yi.Painter")

---@class yi.views.select.CombinedList : yi.views.select.BaseList
---@operator call: yi.views.select.CombinedList
local CombinedList = BaseList + {}

---@param chart_selector rizu.select.ChartSelector
---@param config rizu.config.Config
function CombinedList:new(chart_selector, config)
	BaseList.new(self)
	self.chart_selector = chart_selector
	self.config = config
	self.sdf_batch = love.graphics.newTextBatch(Resources.getSdfFont())
	self.text_batch = love.graphics.newTextBatch(Resources.getFont("regular", 24))
	self.sprite_batch = love.graphics.newSpriteBatch(Resources.atlas)
	self:setWidth(500)
end

function CombinedList:load()
	self.h_set = Painter.getQuadHeight(Resources.quads.set_panel)
	self.h_chart = Painter.getQuadHeight(Resources.quads.chart_panel)
	self.gap = 8
	self.diff_column = self.config:getString(Settings.select.display.diff_column)
	BaseList.load(self)
end

function CombinedList:snapToSelected()
	local sel_set_index = self:getSelectedIndex()
	if sel_set_index then
		local num_charts = self.chart_selector.stores[2]:count()
		local sel_chart_index = self.chart_selector.state:getSecondary().index
		local focus_y, focus_h
		if sel_chart_index and sel_chart_index > 0 and sel_chart_index <= num_charts then
			focus_y = sel_set_index * (self.h_set + self.gap) + self.h_set + self.gap + (sel_chart_index - 1) * (self.h_chart + self.gap)
			focus_h = self.h_chart
		else
			focus_y = sel_set_index * (self.h_set + self.gap)
			focus_h = self.h_set
		end
		local scroll_target = focus_y - ((self.height and self.height > 0) and (self.height - focus_h) / 2 or (540 - focus_h / 2))
		self.scroll_spring:snap(scroll_target)
	end
end

function CombinedList:getSelectedIndex()
	return self.chart_selector.state:getPrimary().index
end

function CombinedList:getItem(index)
	return self.chart_selector.stores[1]:get(index)
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

function CombinedList:addSetToBatch(item, y, is_selected)
	local alpha = is_selected and 1.0 or 0.5
	local center_y = (self.height and self.height > 0) and (self.height / 2) or 540
	local dist = (y + self.h_set / 2) - center_y
	local norm_dist = dist / center_y
	local shift_x = (norm_dist * norm_dist) * 50

	local px = self.width - 477 + shift_x
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

function CombinedList:addChartToBatch(item, y, is_selected)
	local alpha = is_selected and 1.0 or 0.6
	local center_y = (self.height and self.height > 0) and (self.height / 2) or 540
	local dist = (y + self.h_chart / 2) - center_y
	local norm_dist = dist / center_y
	local shift_x = (norm_dist * norm_dist) * 50

	local px = self.width - 437 + shift_x
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
	local sel_set_index = self:getSelectedIndex()
	if not sel_set_index then return end

	local num_charts = self.chart_selector.stores[2]:count()
	local total_chart_height = num_charts * (self.h_chart + self.gap)

	local sel_chart_index = self.chart_selector.state:getSecondary().index

	local focus_y, focus_h
	if sel_chart_index and sel_chart_index > 0 and sel_chart_index <= num_charts then
		focus_y = sel_set_index * (self.h_set + self.gap) + self.h_set + self.gap + (sel_chart_index - 1) * (self.h_chart + self.gap)
		focus_h = self.h_chart
	else
		focus_y = sel_set_index * (self.h_set + self.gap)
		focus_h = self.h_set
	end

	local scroll_target = focus_y - ((self.height and self.height > 0) and (self.height - focus_h) / 2 or (540 - focus_h / 2))
	self.scroll_spring:set(scroll_target)
	self.scroll_spring:update(dt)

	local scroll_y = self.scroll_spring:get()

	self:resetBatches()

	local num_sets = self.chart_selector.stores[1]:count()

	for i = 1, num_sets do
		local set_y
		if i <= sel_set_index then
			set_y = i * (self.h_set + self.gap)
		else
			set_y = i * (self.h_set + self.gap) + total_chart_height
		end

		local screen_y = set_y - scroll_y

		if screen_y + self.h_set >= 0 and screen_y <= self.height then
			local set_item = self.chart_selector.stores[1]:get(i)
			if set_item then
				self:addSetToBatch(set_item, screen_y, i == sel_set_index)
			end
		end

		if i == sel_set_index and num_charts > 0 then
			for c = 1, num_charts do
				local chart_y = sel_set_index * (self.h_set + self.gap) + self.h_set + self.gap + (c - 1) * (self.h_chart + self.gap)
				local chart_screen_y = chart_y - scroll_y

				if chart_screen_y + self.h_chart >= 0 and chart_screen_y <= self.height then
					local chart_item = self.chart_selector.stores[2]:get(c)
					if chart_item then
						local is_chart_selected = (c == sel_chart_index)
						self:addChartToBatch(chart_item, chart_screen_y, is_chart_selected)
					end
				end
			end
		end
	end
end

function CombinedList:draw()
	love.graphics.clear(false, true, false)
	love.graphics.setStencilMode("draw", 1)
	love.graphics.rectangle("fill", 0, 0, self.width, self.height)
	love.graphics.setStencilMode("test")

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(self.sprite_batch)
	love.graphics.draw(self.text_batch)

	Painter.setFontOutline(0.12)
	Painter.setFontThickness(0.45)
	Painter.setFontOutlineColor(Colors.text_shadow)
	Painter.beginTextDrawing()
	love.graphics.draw(self.sdf_batch)
	Painter.endTextDrawing()

	love.graphics.setStencilMode("off")
end

return CombinedList
