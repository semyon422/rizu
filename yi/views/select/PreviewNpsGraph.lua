local View = require("yi.views.View")
local Colors = require("yi.Colors")
local table_util = require("table_util")
local math_util = require("math_util")

---@class yi.PreviewNpsGraph : yi.View
---@overload fun(previewModel: rizu.preview.PreviewModel): yi.PreviewNpsGraph
---@field preview_model rizu.preview.PreviewModel
---@field points number[]
---@field note_times number[]
local PreviewNpsGraph = View + {}

PreviewNpsGraph.MinSamples = 32
PreviewNpsGraph.MaxSamples = 256
PreviewNpsGraph.WindowSeconds = 1
PreviewNpsGraph.BaseNps = 50

function PreviewNpsGraph:load()
	View.load(self)
	self.preview_model = self:getGame().previewModel
	self.note_times = {}
	self.points = {}
	self.dragging = false
	self.hovered = false
	self:setup({
		w = 320,
		h = 56,
		mouse = true,
	})
end

---@param event rizu.AudioPreviewPlayer.RangeEvent
function PreviewNpsGraph:receive(event)
	if event.type == "range" then
		self:rebuild(event.min_time, event.max_time)
	end
end

---@param chart chart.Chart
function PreviewNpsGraph:setChart(chart)
	table_util.clear(self.note_times)
	for _, note in ipairs(chart.notes:getLinkedNotes()) do
		self.note_times[#self.note_times + 1] = note:getStartTime()
	end
end

---@param gx number
---@param gy number
function PreviewNpsGraph:seekFromMouse(gx, gy)
	if self.preview_model:getDuration() <= 0 then
		return
	end

	local lx, _ = self.transform:inverseTransformPoint(gx, gy)
	local width = self:getCalculatedWidth()
	if width <= 0 then
		return
	end

	local progress = math.max(0, math.min(1, lx / width))
	self.preview_model:setRelativePosition(progress)
end

function PreviewNpsGraph:onHover()
	self.hovered = true
end

function PreviewNpsGraph:onHoverLost()
	self.hovered = false
	if not love.mouse.isDown(1) then
		self.dragging = false
	end
end

function PreviewNpsGraph:onMouseDown(e)
	self.dragging = true
	self:seekFromMouse(e.x, e.y)
	return true
end

function PreviewNpsGraph:onMouseUp()
	self.dragging = false
end

function PreviewNpsGraph:onDragStart(e)
	self.dragging = true
	self:seekFromMouse(e.x, e.y)
end

function PreviewNpsGraph:onDrag(e)
	if self.dragging then
		self:seekFromMouse(e.x, e.y)
	end
end

function PreviewNpsGraph:onDragEnd()
	self.dragging = false
end

---@param min_time number
---@param max_time number
function PreviewNpsGraph:rebuild(min_time, max_time)
	local chart = self.preview_model.chartPreview.chart
	if not chart then
		return
	end

	table_util.clear(self.points)
	self:setChart(chart)

	local w, h = self:getCalculatedWidth(), self:getCalculatedHeight()
	local samples = math_util.clamp(math.floor(w), self.MinSamples, self.MaxSamples)

	local duration = max_time - min_time

	if duration <= 0 then
		return
	end

	local bucket_duration = duration / samples
	local window = math.max(self.WindowSeconds, bucket_duration)
	local values = {} ---@type number[]
	local max_value = 0

	for i = 1, samples do
		local bucket_start = min_time + (i - 1) * bucket_duration
		local bucket_end = bucket_start + window
		local count = 0

		for _, start_time in ipairs(self.note_times) do
			if start_time >= bucket_start and start_time < bucket_end then
				count = count + 1
			end
		end

		local nps = count / window
		values[i] = nps
		if nps > max_value then
			max_value = nps
		end
	end
	max_value = math.max(self.BaseNps, max_value)

	if samples < 2 or max_value <= 0 then
		return
	end

	local graph_h = h - 4
	local points = self.points

	for i = 1, samples do
		local x = 1 + (i - 1) * (w - 2) / (samples - 1)
		local y = h - 1 - (values[i] / max_value) * graph_h
		points[#points + 1] = x
		points[#points + 1] = y
	end
end

local dragging = {1, 1, 1, 0.95}
local hovered = {Colors.accent[1], Colors.accent[2], Colors.accent[3], 0.9}

function PreviewNpsGraph:draw()
	local w, h = self:getCalculatedWidth(), self:getCalculatedHeight()
	local border = (self.hovered or self.dragging) and 2 or 1
	love.graphics.setLineWidth(border)
	love.graphics.setColor(Colors.outline)
	love.graphics.rectangle("line", 0.5, 0.5, w - 1, h - 1)

	local points = self.points

	if #points < 2 then
		return
	end

	love.graphics.setColor(Colors.br)
	love.graphics.line(1, h - 1.5, w - 1, h - 1.5)

	local line_color = self.dragging and dragging
		or self.hovered and hovered
		or Colors.accent

	love.graphics.setColor(line_color)
	love.graphics.line(points)

	local progress_x = 1 + self.preview_model:getRelativePosition() * (w - 2)
	love.graphics.setColor(1, 1, 1, 0.35)
	love.graphics.line(progress_x, 1, progress_x, h - 1)
end

return PreviewNpsGraph
