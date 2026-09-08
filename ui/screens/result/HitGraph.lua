local View = require("gui.View")
local Painter = require("gui.Painter")
local SpriteBatch = require("gui.SpriteBatch")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")
local TimingValuesFactory = require("sea.chart.TimingValuesFactory")

---@class ui.screens.result.HitGraph : gui.View
---@operator call: ui.screens.result.HitGraph
---@field sequence table[]
---@field judges_source rizu.IJudgesSource?
---@field timing_values sea.TimingValues?
---@field error_message string?
---@field sprite_batch gui.SpriteBatch?
---@field tooltip ui.views.Tooltip?
local HitGraph = View + {}

local judge_colors = {
	{0.6, 0.8, 1, 1},
	{0.95, 0.796, 0.188, 1},
	{0.07, 0.8, 0.56, 1},
	{0.1, 0.7, 1, 1},
	{1, 0.1, 0.7, 1},
}

---@param tooltip ui.views.Tooltip?
function HitGraph:new(tooltip)
	View.new(self)
	self.sequence = {}
	self.tooltip = tooltip
	self.font = Resources.getFont("regular", 14)
	self.handles_mouse_input = true
end

---@param score_engine rizu.ScoreEngine
function HitGraph:bind(score_engine)
	self.sequence = score_engine.sequence or {}
	self.judges_source = score_engine.judgesSource
	self.timing_values = nil
	self.error_message = nil

	local judges_source = self.judges_source
	if judges_source then
		---@cast judges_source +rizu.ScoreSystem
		if judges_source.timings then
			self.timing_values, self.error_message = TimingValuesFactory:get(
				judges_source.timings,
				judges_source.subtimings
			)
		end
	end
	self:rebuild()
end

function HitGraph:onLayoutChanged()
	self:rebuild()
end

---@param time number
---@return table?
function HitGraph:getSliceAt(time)
	local sequence = self.sequence
	local low, high = 1, #sequence
	local found
	while low <= high do
		local middle = math.floor((low + high) / 2)
		if sequence[middle].base.currentTime <= time then
			found = sequence[middle]
			low = middle + 1
		else
			high = middle - 1
		end
	end
	return found or sequence[1]
end

function HitGraph:update()
	local tooltip = self.tooltip
	if not tooltip then return end

	if not self.mouse_over or #self.sequence == 0 or self.width <= 0 then
		if self.tooltip_visible then
			self.tooltip_visible = false
			tooltip:setText(nil)
		end
		return
	end

	local mouse_x, mouse_y = love.mouse.getPosition()
	local x = self.world_transform:inverseTransformPoint(mouse_x, mouse_y)
	local max_time = self.sequence[#self.sequence].base.currentTime
	local time = math.min(math.max(x / self.width, 0), 1) * max_time
	local slice = self:getSliceAt(time)
	local ns = slice and slice.normalscore
	local base = slice and slice.base
	if not ns or not base then
		if self.tooltip_visible then
			self.tooltip_visible = false
			tooltip:setText(nil)
		end
		return
	end

	self.tooltip_visible = true
	tooltip:setText(("Time: %.3f s\nAccuracy: %.2f ms\nMean: %+.2f ms\nNormalscore: %d"):format(
		time,
		(ns.accuracyAdjusted or 0) * 1000,
		(base.lastMean or 0) * 1000,
		(ns.score or 0) * 10000
	))
	tooltip:followCursor(mouse_x, mouse_y)
end

function HitGraph:rebuild()
	local sequence = self.sequence
	local timing_values = self.timing_values
	local judges_source = self.judges_source
	if not timing_values or not judges_source or #sequence == 0 or self.width <= 0 or self.height <= 0 then
		self.sprite_batch = nil
		return
	end

	local max_time = sequence[#sequence].base.currentTime
	local timing = timing_values.ShortNote.hit
	local delta_min, delta_max = timing[1], timing[2]
	local delta_range = delta_max - delta_min
	if max_time <= 0 or delta_range <= 0 then
		self.sprite_batch = nil
		return
	end

	local hit = Resources.sprites.result_hit
	local pixel = Resources.sprites.pixel
	local hit_width, hit_height = hit:getDimensions()
	local pixel_width, pixel_height = pixel:getDimensions()
	local scale = 0.6
	local plot_width = self.width - hit_width * scale
	local plot_height = self.height - hit_height * scale
	local system = judges_source ---@cast system +rizu.ScoreSystem
	local system_key = system:getKey()
	local batch = SpriteBatch(hit, math.max(#sequence, 1))

	for _, slice in ipairs(sequence) do
		local base = slice.base
		if base.isMiss or base.isEarlyHit then
			local x = math.min(math.max(base.currentTime / max_time, 0), 1) * self.width
			batch:setColor(base.isEarlyHit and {1, 0.5, 0, 1} or Colors.danger)
			batch:add(pixel, x, 0, 0, 1 / pixel_width, self.height / pixel_height)
		else
			local delta = slice.misc.deltaTime
			if delta >= delta_min and delta <= delta_max then
				local x = math.min(math.max(base.currentTime / max_time, 0), 1) * plot_width
				local y = (delta - delta_min) / delta_range * plot_height
				local judge_slice = slice[system_key]
				local color = judge_colors[judge_slice and judge_slice.last_judge] or Colors.text
				batch:setColor(color)
				batch:add(hit, x, y, 0, scale, scale)
			end
		end
	end
	batch:flush()
	self.sprite_batch = batch
	self.delta_min = delta_min
	self.delta_max = delta_max
end

function HitGraph:draw()
	Painter.setColorTable(Colors.surface)
	Resources.sprites.pixel:draw(0, 0, 0, self.width, self.height)

	local timing_values = self.timing_values
	if timing_values then
		local timing = timing_values.ShortNote.hit
		local range = timing[2] - timing[1]
		if range > 0 then
			local zero_y = -timing[1] / range * self.height
			Painter.setColorTable(Colors.divider)
			Resources.sprites.pixel:draw(0, zero_y, 0, self.width, 1)
		end
	end

	if self.sprite_batch then
		Painter.setColorRgb(1, 1, 1)
		self.sprite_batch:draw()
	end

	Painter.setColorTable(Colors.muted)
	love.graphics.setFont(self.font)
	if self.delta_min and self.delta_max then
		love.graphics.print(("%+.1f ms"):format(self.delta_min * 1000), 6, 4)
		love.graphics.print(("%+.1f ms"):format(self.delta_max * 1000), 6, self.height - self.font:getHeight() - 4)
	elseif self.error_message then
		love.graphics.print(self.error_message, 8, 8)
	else
		love.graphics.print("No hit data", 8, 8)
	end
end

return HitGraph
