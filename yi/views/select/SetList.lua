local BaseList = require("yi.views.select.BaseList")
local Resources = require("yi.Resources")
local Colors = require("yi.Colors")

---@class yi.views.select.SetList : yi.views.select.BaseList
---@operator call: yi.views.select.SetList
local SetList = BaseList + {}

---@param chart_selector rizu.select.ChartSelector
function SetList:new(chart_selector)
	BaseList.new(self)
	self.chart_selector = chart_selector
	self.text_batch = love.graphics.newTextBatch(Resources.getFont("regular", 24))
	self.atlas, self.quads = Resources.atlas, Resources.quads
	self:setWidth(500)
end

function SetList:getSelectedIndex()
	return self.chart_selector.state:getPrimary().index
end

function SetList:getItem(index)
	return self.chart_selector.stores[1]:get(index)
end

function SetList:onScroll(e)
	if e.direction_y > 0 then
		self.chart_selector:scrollLevel(1, -1)
	elseif e.direction_y < 0 then
		self.chart_selector:scrollLevel(1, 1)
	end
end

local cs = {Colors.text, ""}

function SetList:resetBatches()
	self.text_batch:clear()
end

function SetList:addToBatch(item, y, is_selected)
	y = y + self.item_height / 4
	local width = self.width
	local font_h = self.text_batch:getFont():getHeight()
	local x_indent = -20

	cs[1] = Colors.text
	cs[2] = item.title or "Unknown"
	self.text_batch:addf(cs, width, "right", x_indent, y)
	cs[1] = Colors.text_muted
	cs[2] = item.artist or "Unknown"
	self.text_batch:addf(cs, width, "right", x_indent, y + font_h)
end

function SetList:draw()
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

return SetList
