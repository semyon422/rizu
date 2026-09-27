local class = require("class")

local lg = love.graphics

---@class rizu.skin.osu.mania.OsuManiaStageRenderer
---@operator call: rizu.skin.osu.mania.OsuManiaStageRenderer
local OsuManiaStageRenderer = class()

function OsuManiaStageRenderer:update(dt) end

---@param renderer rizu.skin.osu.OsuManiaRenderer
---@param name string?
---@param fallback string
---@return love.Image?
local function get_image(renderer, name, fallback)
	if name and tonumber(name) then name = nil end
	return renderer.skin_graphics:getFrames(name, fallback)[1]
end

---@param renderer rizu.skin.osu.OsuManiaRenderer
---@param first integer
---@param last integer
---@param lane_widths number[]
---@param lane_xs number[]
function OsuManiaStageRenderer:drawStagePair(renderer, first, last, lane_widths, lane_xs)
	if first > last then return end
	local left = lane_xs[first] - lane_widths[first] / 2
	local right = lane_xs[last] + lane_widths[last] / 2
	local height = 480
	local stage_left = get_image(renderer, renderer:getSkinValue("StageLeft"), "mania-stage-left")
	if stage_left then
		local image_width, image_height = stage_left:getDimensions()
		local width = image_width * height / image_height
		lg.setColor(1, 1, 1, 1)
		lg.draw(stage_left, left, height, 0, width / image_width, height / image_height,
			image_width, image_height)
	end
	local stage_right = get_image(renderer, renderer:getSkinValue("StageRight"), "mania-stage-right")
	if stage_right then
		local image_width, image_height = stage_right:getDimensions()
		local width = image_width * height / image_height
		lg.setColor(1, 1, 1, 1)
		lg.draw(stage_right, right, height, 0, width / image_width, height / image_height,
			0, image_height)
	end
end

---@param renderer rizu.skin.osu.OsuManiaRenderer
---@param field_left number
---@param field_width number
---@param lane_widths number[]
---@param lane_xs number[]
---@param hit_y number
function OsuManiaStageRenderer:draw(renderer, field_left, field_width, lane_widths, lane_xs, hit_y)
	local stage_hint = get_image(renderer, renderer:getSkinValue("StageHint"), "mania-stage-hint")
	if stage_hint then
		local _, image_height = stage_hint:getDimensions()
		lg.setColor(1, 1, 1, 1)
		lg.draw(stage_hint, field_left, hit_y - image_height / 2, 0, field_width / stage_hint:getWidth(), 1)
	end

	local middle = math.floor(renderer.columns / 2)
	if renderer.split_stages then
		self:drawStagePair(renderer, 1, middle, lane_widths, lane_xs)
		self:drawStagePair(renderer, middle + 1, renderer.columns, lane_widths, lane_xs)
	else
		self:drawStagePair(renderer, 1, renderer.columns, lane_widths, lane_xs)
	end

	local stage_bottom = get_image(renderer, renderer:getSkinValue("StageBottom"), "mania-stage-bottom")
	if stage_bottom then
		local left = lane_xs[1] - lane_widths[1] / 2
		local right = lane_xs[renderer.columns] + lane_widths[renderer.columns] / 2
		lg.setColor(1, 1, 1, 1)
		lg.draw(stage_bottom, (left + right) / 2, 480, 0, 1, 1,
			stage_bottom:getWidth() / 2, stage_bottom:getHeight())
	end
end

return OsuManiaStageRenderer
