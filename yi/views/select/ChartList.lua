local BaseList = require("yi.views.select.BaseList")
local Resources = require("yi.Resources")
local Settings = require("rizu.config.schemas.Settings")
local Color = require("yi.Color")
local SpringValue = require("gui.anim.SpringValue")

---@class yi.views.select.ChartList : yi.views.select.BaseList
---@operator call: yi.views.select.ChartList
local ChartList = BaseList + {}

---@param chart_selector rizu.select.ChartSelector
---@param config rizu.config.Config
function ChartList:new(chart_selector, config)
	BaseList.new(self)
	self.chart_selector = chart_selector
	self.config = config
	self.text_batch = love.graphics.newTextBatch(Resources.getFont("regular", 24))
	self.sprite_batch = love.graphics.newSpriteBatch(Resources.atlas)
	self.visible_items = 5
	self.gap_half = 5
	local _, _, w, h = Resources.quads.chart_panel:getViewport()
	self:setSize(450, h * self.visible_items)
	self.slide_in = SpringValue()
end

function ChartList:load()
	BaseList.load(self)

	local th = self.text_batch:getFont():getHeight() ---@type number
	self.text_y = (self.item_height - th) / 2 + 2
	self.diff_column = self.config:getString(Settings.select.display.diff_column)
end

function ChartList:onScroll(e)
	if e.direction_y > 0 then
		self.chart_selector:scrollLevel(2, -1)
	elseif e.direction_y < 0 then
		self.chart_selector:scrollLevel(2, 1)
	end
end

function ChartList:getSelectedIndex()
	return self.chart_selector.state:getSecondary().index
end

---@return rizu.library.LocatedChartview?
function ChartList:getItem(index)
	return self.chart_selector.stores[2]:get(index)
end

function ChartList:resetBatches()
	self.text_batch:clear()
	self.sprite_batch:clear()
end

local white = {1, 1, 1, 1}
local shadow_string = {{0, 0, 0, 0.5}, ""}

---@param item rizu.library.LocatedChartview
---@param y number
function ChartList:addToBatch(item, y, is_selected)
	local color = white

	if self.diff_column == "enps_diff" then
		Color.enpsToColor(item.enps_diff or 0, color)
	elseif self.diff_column == "msd_diff" then
		Color.msdToColor(item.msd_diff or 0, color)
	elseif self.diff_column == "osu_diff" then
		Color.osuToColor(item.osu_diff or 0, color)
	end

	color[4] = is_selected and 1 or 0.4
	self.sprite_batch:setColor(color[1], color[2], color[3], color[4])
	self.sprite_batch:add(Resources.quads.chart_panel, 0, y)

	if item.inputmode then
		local text = item.inputmode:gsub("key", "K"):gsub("scratch", "S")
		shadow_string[2] = text
		self.text_batch:addf(shadow_string, 90, "center", 5 + 2, y + self.text_y + 2)
		self.text_batch:addf(text, 90, "center", 5, y + self.text_y)
	end

	if item.name then
		shadow_string[2] = item.name
		self.text_batch:add(shadow_string, 100 + 2, y + self.text_y + 2)
		self.text_batch:add(item.name, 100, y + self.text_y)
	end
end

function ChartList:update(dt)
	if self.chart_selector.stores[2]:count() == 1 then
		return
	end

	if self.pending_slide_in then
		self.pending_slide_in = false
		self.slide_in:snap(0)
		self.slide_in:set(1)
		self:snapToSelected()
	end

	BaseList.update(self, dt)
	self.slide_in:update(dt)
end

function ChartList:slideIn()
	self.pending_slide_in = true
end

function ChartList:draw()
	if self.chart_selector.stores[2]:count() == 1 then
		return
	end

	love.graphics.clear(false, true, false)
	love.graphics.setStencilMode("draw", 1)
	love.graphics.rectangle("fill", 0, 0, self.width, self.height)
	love.graphics.setStencilMode("test")

	love.graphics.setColor(1, 1, 1, self.slide_in:get())
	love.graphics.translate((1 - self.slide_in:get()) * 30, 0)
	love.graphics.draw(self.sprite_batch)
	love.graphics.draw(self.text_batch)

	love.graphics.setStencilMode("off")
end

return ChartList
