local class = require("class")

local lg = love.graphics
local FIELD_HEIGHT = 480

---@class rizu.skin.osu.mania.OsuManiaFieldRenderer
---@operator call: rizu.skin.osu.mania.OsuManiaFieldRenderer
local OsuManiaFieldRenderer = class()

function OsuManiaFieldRenderer:update(dt) end

---@param renderer rizu.skin.osu.OsuManiaRenderer
---@param field_left number
---@param field_width number
function OsuManiaFieldRenderer:drawBackground(renderer, field_left, field_width)
	lg.setColor(0.025, 0.03, 0.045, 0.94)
	lg.rectangle("fill", field_left, 0, field_width, FIELD_HEIGHT)
end

---@param renderer rizu.skin.osu.OsuManiaRenderer
---@param column integer
---@param lane_width number
---@param lane_x number
function OsuManiaFieldRenderer:drawLane(renderer, column, lane_width, lane_x)
	local color = renderer:getSkinColor("Colour" .. column, {0, 0, 0, 1})
	lg.setColor(color[1], color[2], color[3], color[4])
	lg.rectangle("fill", lane_x - lane_width / 2, 0, lane_width, FIELD_HEIGHT)
end

---@param renderer rizu.skin.osu.OsuManiaRenderer
---@param lane_widths number[]
---@param lane_xs number[]
function OsuManiaFieldRenderer:drawLanes(renderer, lane_widths, lane_xs)
	for column = 1, renderer.columns do
		self:drawLane(renderer, column, lane_widths[column], lane_xs[column])
	end
end

---@param renderer rizu.skin.osu.OsuManiaRenderer
---@param field_left number
---@param field_width number
---@param lane_widths number[]
---@param lane_xs number[]
---@param hit_y number
---@param width_scale number
function OsuManiaFieldRenderer:drawGuides(renderer, field_left, field_width, lane_widths, lane_xs, hit_y, width_scale)
	local line_color = renderer:getSkinColor("ColourColumnLine", {1, 1, 1, 1})
	for edge = 0, renderer.columns do
		local edge_x = edge == 0 and field_left or lane_xs[edge] + lane_widths[edge] / 2
		local line_width = (renderer.column_lines[edge + 1] or 0) * width_scale
		if line_width > 0 then
			lg.setColor(line_color[1], line_color[2], line_color[3], line_color[4] * 0.7)
			lg.rectangle("fill", edge_x - line_width / 2, 0, line_width, FIELD_HEIGHT)
		end
	end
	if renderer.judgement_line then
		local color = renderer:getSkinColor("ColourJudgementLine", {1, 1, 1, 1})
		lg.setColor(color[1], color[2], color[3], color[4] * 0.9)
		lg.rectangle("fill", field_left, hit_y - 1, field_width, 2)
	end
end

---@param renderer rizu.skin.osu.OsuManiaRenderer
---@param field_left number
---@param field_width number
---@param lane_widths number[]
---@param lane_xs number[]
---@param hit_y number
---@param width_scale number
function OsuManiaFieldRenderer:draw(renderer, field_left, field_width, lane_widths, lane_xs, hit_y, width_scale)
	self:drawBackground(renderer, field_left, field_width)
	self:drawLanes(renderer, lane_widths, lane_xs)
	self:drawGuides(renderer, field_left, field_width, lane_widths, lane_xs, hit_y, width_scale)
end

return OsuManiaFieldRenderer
