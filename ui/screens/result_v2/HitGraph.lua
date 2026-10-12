local View = require("gui.View")
local Painter = require("gui.Painter")
local SpriteBatch = require("gui.SpriteBatch")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")
local ScoreSystemFormatter = require("ui.formatters.ScoreSystemFormatter")

---@class ui.screens.result_v2.HitGraph : gui.View
---@operator call: ui.screens.result_v2.HitGraph
---@field hits rizu.api.Result.Hit[]
---@field formatter ui.formatters.ScoreSystemFormatter?
---@field delta_min number?
---@field delta_max number?
---@field error_message string?
---@field sprite_batch gui.SpriteBatch?
---@field tooltip ui.views.Tooltip?
---@field background gui.Color? Nil draws no background.
local HitGraph = View + {}

---@param tooltip ui.views.Tooltip?
---@param background gui.Color? Defaults to the surface color; pass `false` for a transparent graph.
function HitGraph:new(tooltip, background)
	View.new(self)
	if background == nil then
		background = Colors.surface
	end
	self.background = background or nil
	self.hits = {}
	self.tooltip = tooltip
	self.font = Resources.getFont("regular", 14)
	self.handles_mouse_input = true
end

---@param result rizu.api.Result
function HitGraph:bind(result)
	self.hits = result:getHits()
	self.formatter = ScoreSystemFormatter(result:getJudging() --[[@as rizu.ScoreSystem]])
	self.delta_min, self.delta_max, self.error_message = result:getHitWindow()
	self:rebuild()
end

function HitGraph:onLayoutChanged()
	self:rebuild()
end

---@param time number
---@return rizu.api.Result.Hit?
function HitGraph:getHitAt(time)
	local hits = self.hits
	local low, high = 1, #hits
	local found ---@type rizu.api.Result.Hit?
	while low <= high do
		local middle = math.floor((low + high) / 2)
		if hits[middle].time <= time then
			found = hits[middle]
			low = middle + 1
		else
			high = middle - 1
		end
	end
	return found or hits[1]
end

function HitGraph:update()
	local tooltip = self.tooltip
	if not tooltip then return end

	if not self.mouse_over or #self.hits == 0 or self.width <= 0 then
		if self.tooltip_visible then
			self.tooltip_visible = false
			tooltip:setText(nil)
		end
		return
	end

	local mouse_x, mouse_y = love.mouse.getPosition()
	local x = self.world_transform:inverseTransformPoint(mouse_x, mouse_y)
	local max_time = self.hits[#self.hits].time
	local time = math.min(math.max(x / self.width, 0), 1) * max_time
	local hit = assert(self:getHitAt(time))

	self.tooltip_visible = true
	tooltip:setText(("Time: %.3f s\nAccuracy: %.2f ms\nMean: %+.2f ms\nNormalscore: %d"):format(
		time,
		hit.accuracy * 1000,
		hit.mean * 1000,
		hit.normalscore * 10000
	))
	tooltip:followCursor(mouse_x, mouse_y)
end

function HitGraph:rebuild()
	local hits = self.hits
	local formatter = self.formatter
	local delta_min, delta_max = self.delta_min, self.delta_max
	self.sprite_batch = nil
	if not formatter or not delta_min or not delta_max or #hits == 0 or self.width <= 0 or self.height <= 0 then
		return
	end

	local max_time = hits[#hits].time
	local delta_range = delta_max - delta_min
	if max_time <= 0 or delta_range <= 0 then
		return
	end

	local hit_sprite = Resources.sprites.result_hit
	local pixel = Resources.sprites.pixel
	local hit_width, hit_height = hit_sprite:getDimensions()
	local pixel_width, pixel_height = pixel:getDimensions()
	local scale = 0.6
	local plot_width = self.width - hit_width * scale
	local plot_height = self.height - hit_height * scale
	local batch = SpriteBatch(hit_sprite, #hits)

	for _, hit in ipairs(hits) do
		local progress = math.min(math.max(hit.time / max_time, 0), 1)
		if hit.kind ~= "hit" then
			batch:setColor(hit.kind == "early" and {1, 0.5, 0, 1} or Colors.danger)
			batch:add(pixel, progress * self.width, 0, 0, 1 / pixel_width, self.height / pixel_height)
		elseif hit.delta >= delta_min and hit.delta <= delta_max then
			local y = (hit.delta - delta_min) / delta_range * plot_height
			batch:setColor(hit.judge and formatter:getJudgeColor(hit.judge) or Colors.text)
			batch:add(hit_sprite, progress * plot_width, y, 0, scale, scale)
		end
	end
	batch:flush()
	self.sprite_batch = batch
end

function HitGraph:draw()
	if self.background then
		Painter.setColorTable(self.background)
		Resources.sprites.pixel:draw(0, 0, 0, self.width, self.height)
	end

	if self.delta_min and self.delta_max then
		local range = self.delta_max - self.delta_min
		if range > 0 then
			local zero_y = -self.delta_min / range * self.height
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
	if self.sprite_batch then
		love.graphics.print(("%+.1f ms"):format(self.delta_min * 1000), 6, 4)
		love.graphics.print(("%+.1f ms"):format(self.delta_max * 1000), 6, self.height - self.font:getHeight() - 4)
	elseif self.error_message then
		love.graphics.print(self.error_message, 8, 8)
	else
		love.graphics.print("No hit data", 8, 8)
	end
end

return HitGraph
