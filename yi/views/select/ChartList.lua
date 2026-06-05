local View = require("gui.View")
local Resources = require("yi.Resources")
local SpringValue = require("gui.anim.SpringValue")
local Colors = require("yi.Colors")

---@class yi.views.select.ChartList : gui.View
---@operator call: yi.views.select.ChartList
local ChartList = View + {}

local ITEMS_ON_SCREEN = 9

---@param chart_selector rizu.select.ChartSelector
function ChartList:new(chart_selector)
	View.new(self)
	self.chart_selector = chart_selector
	self.text_batch = love.graphics.newTextBatch(Resources.getScaledFont("regular", 24))
	self.scroll_spring = SpringValue()
	self.atlas, self.quads = Resources.atlas, Resources.quads
	self.handles_mouse_input = true
end

function ChartList:load()
	self:setSize(500, self.box.height)
	self.pivot = {1, 0}

	self.item_height = self.height / ITEMS_ON_SCREEN

	self.scroll_spring:snap(self:getSelectedIndex())
end

function ChartList:getSelectedIndex()
	return self.chart_selector.state:getPrimary().index
end

function ChartList:onScroll(e)
	if e.direction_y > 0 then
		self.chart_selector:scrollLevel(1, -1)
	elseif e.direction_y < 0 then
		self.chart_selector:scrollLevel(1, 1)
	end
end

local cs = {Colors.text, ""}

function ChartList:update(dt)
	local selected_index = self:getSelectedIndex()

	self.scroll_spring:set(selected_index)
	self.scroll_spring:update(dt)

	self.text_batch:clear()
	local item_height = self.item_height

	local scroll_index = self.scroll_spring:get()
	local centered = scroll_index - ITEMS_ON_SCREEN / 2
	local first_index = math.floor(centered)
	local pixel_offset = (centered - math.floor(centered)) * item_height

	local width = self.width
	local font_h = self.text_batch:getFont():getHeight()
	local x_indent = -20

	for i = 0, ITEMS_ON_SCREEN do
		local item_index = first_index + i
		local item = self.chart_selector.stores[1]:get(item_index)
		if item then
			local item_y = i * item_height - pixel_offset - item_height / 4
			cs[1] = Colors.text
			cs[2] = item.title or "Unknown"
			self.text_batch:addf(cs, width, "right", x_indent, item_y)
			cs[1] = Colors.text_muted
			cs[2] = item.artist or "Unknown"
			self.text_batch:addf(cs, width, "right", x_indent, item_y + font_h)
		end
	end
end

function ChartList:draw()
	local g = self.quads.chart_list_selected_gradient
	local _, _, w, _ = g:getViewport()

	local c = Colors.accent
	love.graphics.setColor(c)
	love.graphics.draw(self.atlas, self.quads.pixel,
		self.width - 5,
		(self.height - self.item_height) / 2,
		0,
		5,
		self.item_height
	)
	love.graphics.setColor(c[1], c[2], c[3], 0.3)
	love.graphics.draw(self.atlas, self.quads.chart_list_selected_gradient,
		self.width - 300,
		(self.height - self.item_height) / 2,
		0,
		295 / w,
		self.item_height
	)
	love.graphics.setColor(1, 1, 1)
	love.graphics.draw(self.text_batch)
end

return ChartList
