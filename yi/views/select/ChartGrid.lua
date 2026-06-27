local View = require("gui.View")
local Resources = require("yi.Resources")
local Painter = require("yi.Painter")
local Colors = require("yi.Colors")
local Color = require("yi.Color")
local Sounds = require("yi.Sounds")

---@class yi.views.select.ChartGrid.Item
---@field id integer
---@field difficulty string
---@field difficulty_color gui.Color
---@field inputmode string
---@field name string

---@class yi.views.select.ChartGrid : gui.View
---@operator call: yi.views.select.ChartGrid
---@field items yi.views.select.ChartGrid.Item[]
local ChartGrid = View + {}

local COL_WIDTH = 345
local COL_X_GAP = 5
local COL_Y_GAP = 5

---@param chart_selector rizu.select.ChartSelector
function ChartGrid:new(chart_selector)
	View.new(self)
	self.chart_selector = chart_selector
	self.items = {}
	self.meta_batch = love.graphics.newTextBatch(Resources.getFont("regular", 24)) ---@type love.Text
	self.names_batch = love.graphics.newTextBatch(Resources.getFont("cjk_regular", 24)) ---@type love.Text
	self.handles_keyboard_input = true
end

function ChartGrid:load()
	local w, h = self.box:getDimensions()
	local cols = math.max(1, math.floor(w / COL_WIDTH))
	local total_gap_x = COL_X_GAP * (cols - 1)
	local width_per_col = (w - total_gap_x) / cols

	self.columns = cols
	self.width_per_col = width_per_col
end

function ChartGrid:reloadItems()
	self.items = {}
	local secondary = self.chart_selector.stores[2]
	local count = secondary:count()

	for i = 1, count do
		local item = secondary:get(i)
		if item then
			local enps = item.enps_diff or 0
			table.insert(self.items, {
				id = i,
				name = item.name or "Unknown",
				difficulty = ("%0.01f"):format(enps),
				difficulty_color = Color.enpsToColor(enps, {1, 1, 1, 1}),
				inputmode = (item.inputmode or "?"):gsub("key", "K"):gsub("scratch", "S")
			})
		end
	end
end

function ChartGrid:onKeyDown(e)
	if e.key == "h" then
		self.chart_selector:scrollLevel(2, -1)
		Sounds.play("chart_changed")
		return true
	elseif e.key == "l" then
		self.chart_selector:scrollLevel(2, 1)
		Sounds.play("chart_changed")
		return true
	end
end

local cs = {{1, 1, 1, 1}, ""}

function ChartGrid:draw()
	local cap = Resources.quads.grid_item_cap_right
	local body = Resources.quads.grid_item_body
	local cap_w = Painter.getQuadWidth(cap)
	local body_w = Painter.getQuadWidth(body)
	local body_s = (self.width_per_col - cap_w) / body_w

	local stroke_left = Resources.quads.grid_item_stroke_left
	local stroke_middle = Resources.quads.grid_item_stroke_middle
	local stroke_right = Resources.quads.grid_item_stroke_right
	local stroke_left_w = Painter.getQuadWidth(stroke_left)
	local stroke_middle_w = Painter.getQuadWidth(stroke_middle)
	local stroke_right_w = Painter.getQuadWidth(stroke_right)
	local stroke_middle_s = (self.width_per_col - stroke_left_w - stroke_right_w) / stroke_middle_w

	self.meta_batch:clear()
	self.names_batch:clear()

	love.graphics.clear(false, true, false)
	love.graphics.setStencilMode("draw", 1)
	love.graphics.rectangle("fill", 0, 0, self.box:getDimensions())
	love.graphics.setStencilMode("test")

	for i, v in ipairs(self.items) do
		local col = (i - 1) % self.columns
		local row = math.floor((i - 1) / self.columns)
		local x = col * (self.width_per_col + COL_X_GAP)
		local y = row * (42 + COL_Y_GAP)
		local c = v.difficulty_color
		if self.chart_selector.state:getSecondary().index == v.id then
			love.graphics.setColor(c[1], c[2], c[3], 0.4)
			love.graphics.draw(Resources.atlas, body, x, y, 0, body_s, 1)
			love.graphics.draw(Resources.atlas, cap, x + (body_w * body_s), y)
			love.graphics.setColor(Colors.accent)
			love.graphics.draw(Resources.atlas, stroke_left, x, y)
			love.graphics.draw(Resources.atlas, stroke_middle, x + stroke_left_w, y, 0, stroke_middle_s, 1)
			love.graphics.draw(Resources.atlas, stroke_right, x + self.width_per_col - stroke_right_w, y)
		else
			love.graphics.setColor(c[1], c[2], c[3], 0.2)
			love.graphics.draw(Resources.atlas, body, x, y, 0, body_s, 1)
			love.graphics.draw(Resources.atlas, cap, x + (body_w * body_s), y)
		end
		cs[1] = v.difficulty_color
		cs[2] = v.difficulty
		self.meta_batch:add(cs, x + 12, y + 7)
		self.meta_batch:add(v.inputmode, x + 86, y + 7)
		self.names_batch:add(v.name, x + 134, y + 1)
	end

	love.graphics.setColor(1, 1, 1)
	love.graphics.draw(self.meta_batch)
	love.graphics.draw(self.names_batch)
	love.graphics.setStencilMode("off")
end
return ChartGrid
