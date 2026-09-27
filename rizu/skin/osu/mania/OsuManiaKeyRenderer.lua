local class = require("class")

local lg = love.graphics
local FIELD_HEIGHT = 480

---@class rizu.skin.osu.mania.OsuManiaKeyRenderer
---@operator call: rizu.skin.osu.mania.OsuManiaKeyRenderer
local OsuManiaKeyRenderer = class()

function OsuManiaKeyRenderer:update(dt) end

---@param renderer rizu.skin.osu.OsuManiaRenderer
---@param engine rizu.RhythmEngine
---@param lane_widths number[]
---@param lane_xs number[]
---@param hit_y number
function OsuManiaKeyRenderer:draw(renderer, engine, lane_widths, lane_xs, hit_y)
	for column = 1, renderer.columns do
		local suffix = renderer:getColumnSuffix(column - 1)
		local key_name = renderer:getSkinValue("KeyImage" .. (column - 1))
		local down_name = renderer:getSkinValue("KeyImage" .. (column - 1) .. "D")
		local input = renderer.inputs[column]
		local engine_column = renderer.engine_input_map[input] or column
		local pressed = engine.isColumnPressed and engine:isColumnPressed(engine_column) or false
		local key = renderer:getFirstFrame(pressed and down_name or key_name)
		if not key and pressed then key = renderer:getFirstFrame(key_name) end
		if not key then key = renderer:getFirstFrame("mania-key" .. suffix .. (pressed and "D" or "")) end
		if not key and pressed then key = renderer:getFirstFrame("mania-key" .. suffix) end
		if key then
			local draw_width = lane_widths[column]
			local flip_value = renderer:getSkinValue("KeyFlipWhenUpsideDown" .. (column - 1)
				.. (pressed and "D" or ""))
			if not flip_value then
				flip_value = renderer:getSkinValue("KeyFlipWhenUpsideDown" .. (column - 1))
			end
			local flip = renderer.upside_down and (flip_value and (flip_value:lower() == "true"
				or tonumber(flip_value) == 1) or renderer.key_flip)
			local image_width, image_height = key:getDimensions()
			local scale_x, scale_y = draw_width / image_width, FIELD_HEIGHT / 768
			lg.setColor(1, 1, 1, 1)
			if renderer.upside_down then
				if flip then
					lg.draw(key, lane_xs[column], 0, 0, scale_x, -scale_y, image_width / 2, image_height)
				else
					lg.draw(key, lane_xs[column], 0, 0, scale_x, scale_y, image_width / 2, 0)
				end
			elseif flip then
				lg.draw(key, lane_xs[column], FIELD_HEIGHT, 0, scale_x, -scale_y, image_width / 2, 0)
			else
				lg.draw(key, lane_xs[column], FIELD_HEIGHT, 0, scale_x, scale_y,
					image_width / 2, image_height)
			end
		else
			lg.setColor(1, 1, 1, pressed and 0.8 or 0.22)
			lg.rectangle("fill", lane_xs[column] - lane_widths[column] / 2, hit_y - 5,
				lane_widths[column], 10)
		end
	end
end

return OsuManiaKeyRenderer
