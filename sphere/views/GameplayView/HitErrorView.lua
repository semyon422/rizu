local transform = require("gfx_util").transform
local map = require("math_util").map
local class = require("class")
local inside = require("table_util").inside

---@class sphere.HitErrorView
---@operator call: sphere.HitErrorView
local HitErrorView = class()

HitErrorView.colors = {
	sphere = {
		{1, 1, 1, 1},
		{1, 0.6, 0.4, 1},
	},
	osuod = {
		{0.6, 0.8, 1, 1},
		{0.95, 0.796, 0.188, 1},
		{0.07, 0.8, 0.56, 1},
		{0.1, 0.39, 1, 1},
		{0.42, 0.48, 0.51, 1},
	},
	etternaj = {
		{0.6, 0.8, 1, 1},
		{0.95, 0.796, 0.188, 1},
		{0.07, 0.8, 0.56, 1},
		{0.1, 0.7, 1, 1},
		{1, 0.1, 0.7, 1},
	},
	quaver = {
		{1, 1, 0.71, 1},
		{1, 0.91, 0.44, 1},
		{0.38, 0.96, 0.47, 1},
		{0.25, 0.7, 0.75, 1},
		{0.72, 0.46, 0.65, 1},
	},
	bmsrank = {
		{0.6, 0.8, 1, 1},
		{0.95, 0.796, 0.188, 1},
		{1, 0.69, 0.24, 1},
		{1, 0.5, 0.24, 1},
	},
}

function HitErrorView:load()
	---@type rizu.ScoreEngine
	local score_engine = self.game.rhythm_engine.score_engine

	self.judgesSource = score_engine.judgesSource
	self.sequence = score_engine.sequence
end

local miss = {1, 0, 0, 1}

---@param value any
---@param unit any
---@param judgesSource rizu.IJudgesSource
---@param slice table
---@return table
function HitErrorView.color(value, unit, judgesSource, slice)
	local index = slice.last_judge
	return HitErrorView.colors[judgesSource.timings.name][index] or miss
end

function HitErrorView:draw()
	if self.show and not self.show(self) then
		return
	end

	local tf = transform(self.transform):translate(self.x, self.y)
	love.graphics.replaceTransform(tf)

	if self.background then
		self:drawBackground()
	end

	local points = self.sequence
	local fade = 0
	for i = #points, #points - self.count, -1 do
		if not points[i] then
			break
		end
		self:drawPoint(points[i], fade)
		fade = fade + 1
	end

	if self.origin then
		self:drawOrigin()
	end
end

function HitErrorView:drawBackground()
	love.graphics.setColor(self.background.color)
	love.graphics.rectangle(
		"fill",
		-self.w / 2,
		0,
		self.w,
		self.h
	)
end

function HitErrorView:drawOrigin()
	local origin = self.origin

	love.graphics.setColor(origin.color)
	love.graphics.rectangle(
		"fill",
		-origin.w / 2,
		-(origin.h - self.h) / 2,
		origin.w,
		origin.h
	)
end

---@param point table
---@param fade number
function HitErrorView:drawPoint(point, fade)
	local color = self.color
	local radius = self.radius

	local value = point.misc.deltaTime
	local unit = inside(point, self.unit)
	if type(value) == "nil" then
		value = tonumber(self.value) or 0
	end
	if type(unit) == "nil" then
		unit = tonumber(self.unit) or 1
	end

	if type(color) == "function" then
		local scoreSystem = self.judgesSource
		---@cast scoreSystem +rizu.ScoreSystem, -rizu.IJudgesSource
		local slice = point[scoreSystem:getKey()]

		color = color(value, unit, self.judgesSource, slice)
	end
	local alpha = color[4]
	color[4] = color[4] * map(fade, 0, self.count, 1, 0)
	love.graphics.setColor(color)
	color[4] = alpha

	local x = map(value, 0, unit, 0, self.w / 2)
	love.graphics.rectangle("fill", x - radius, 0, radius * 2, self.h)
end

return HitErrorView
