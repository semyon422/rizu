local class = require("class")
local OsuImage = require("rizu.skin.osu.OsuImage")

local lg = love.graphics
local FIELD_HEIGHT = 480

---@class rizu.skin.osu.mania.OsuManiaKeyRenderer.State
---@field pressed boolean
---@field releasing boolean
---@field release_elapsed number

---@class rizu.skin.osu.mania.OsuManiaKeyRenderer
---@operator call: rizu.skin.osu.mania.OsuManiaKeyRenderer
---@field private states rizu.skin.osu.mania.OsuManiaKeyRenderer.State[]
local OsuManiaKeyRenderer = class()

local KEY_RELEASE_DURATION = 0.08

function OsuManiaKeyRenderer:new()
	self.states = {}
end

function OsuManiaKeyRenderer:update(dt)
	for _, state in ipairs(self.states) do
		if state.releasing then
			state.release_elapsed = math.min(KEY_RELEASE_DURATION, state.release_elapsed + math.max(dt, 0))
			if state.release_elapsed >= KEY_RELEASE_DURATION then
				state.releasing = false
			end
		end
	end
end

---@param renderer rizu.skin.osu.OsuManiaRenderer
---@param column integer
---@param pressed boolean
---@return rizu.skin.osu.OsuSkinGraphics.Image?
local function get_key_image(renderer, column, pressed)
	local suffix = renderer:getColumnSuffix(column - 1)
	local key_name = renderer:getSkinValue("KeyImage" .. (column - 1))
	local down_name = renderer:getSkinValue("KeyImage" .. (column - 1) .. "D")
	local image_name = pressed and down_name or key_name
	local image = renderer:getFirstFrame(image_name)
	if not image and pressed then image = renderer:getFirstFrame(key_name) end
	if not image then
		image = renderer:getFirstFrame("mania-key" .. suffix .. (pressed and "D" or ""))
	end
	if not image and pressed then image = renderer:getFirstFrame("mania-key" .. suffix) end
	return image
end

---@param renderer rizu.skin.osu.OsuManiaRenderer
---@param column integer
---@param pressed boolean
---@return boolean
local function get_key_flip(renderer, column, pressed)
	local flip_value = renderer:getSkinValue("KeyFlipWhenUpsideDown" .. (column - 1)
		.. (pressed and "D" or ""))
	if not flip_value then
		flip_value = renderer:getSkinValue("KeyFlipWhenUpsideDown" .. (column - 1))
	end
	local flip = flip_value and (flip_value:lower() == "true" or tonumber(flip_value) == 1)
	return renderer.upside_down and (flip or renderer.key_flip)
end

---@param renderer rizu.skin.osu.OsuManiaRenderer
---@param image rizu.skin.osu.OsuSkinGraphics.Image
---@param x number
---@param width number
---@param flip boolean
---@param upside_down boolean
---@param alpha number
local function draw_key(renderer, image, x, width, flip, upside_down, alpha)
	if not image.texture and renderer.skin_graphics.batch then renderer.skin_graphics.batch:flush() end
	local image_width, image_height = OsuImage.dimensions(image)
	local scale_x, scale_y = width / image_width, FIELD_HEIGHT / 768
	lg.setColor(1, 1, 1, alpha)
	if upside_down then
		if flip then
			OsuImage.draw(image, x, 0, 0, scale_x, -scale_y, image_width / 2, image_height)
		else
			OsuImage.draw(image, x, 0, 0, scale_x, scale_y, image_width / 2, 0)
		end
	elseif flip then
		OsuImage.draw(image, x, FIELD_HEIGHT, 0, scale_x, -scale_y, image_width / 2, 0)
	else
		OsuImage.draw(image, x, FIELD_HEIGHT, 0, scale_x, scale_y, image_width / 2, image_height)
	end
end

---@param renderer rizu.skin.osu.OsuManiaRenderer
---@param engine rizu.RhythmEngine
---@param lane_widths number[]
---@param lane_xs number[]
---@param hit_y number
function OsuManiaKeyRenderer:draw(renderer, engine, lane_widths, lane_xs, hit_y)
	for column = 1, renderer.columns do
		local input = renderer.inputs[column]
		local engine_column = renderer.engine_input_map[input] or column
		local pressed = engine.isColumnPressed and engine:isColumnPressed(engine_column) or false
		local state = self.states[column]
		if not state then
			state = {pressed = pressed, releasing = false, release_elapsed = 0}
			self.states[column] = state
		elseif pressed ~= state.pressed then
			if pressed then
				state.releasing = false
				state.release_elapsed = 0
			else
				state.releasing = true
				state.release_elapsed = 0
			end
			state.pressed = pressed
		end

		local up = get_key_image(renderer, column, false)
		local down = get_key_image(renderer, column, true)
		if not down then down = up end
		local up_flip = get_key_flip(renderer, column, false)
		local down_flip = get_key_flip(renderer, column, true)
		if up and down then
			local draw_width = lane_widths[column]
			if state.releasing and up ~= down then
				local progress = state.release_elapsed / KEY_RELEASE_DURATION
				draw_key(renderer, down, lane_xs[column], draw_width, down_flip, renderer.upside_down, 1 - progress)
				draw_key(renderer, up, lane_xs[column], draw_width, up_flip, renderer.upside_down, progress)
			elseif pressed then
				draw_key(renderer, down, lane_xs[column], draw_width, down_flip, renderer.upside_down, 1)
			else
				draw_key(renderer, up, lane_xs[column], draw_width, up_flip, renderer.upside_down, 1)
			end
		elseif up or down then
			local image = up or down
			assert(image)
			draw_key(renderer, image, lane_xs[column], lane_widths[column], pressed and down_flip or up_flip,
				renderer.upside_down, 1)
		else
			lg.setColor(1, 1, 1, pressed and 0.8 or 0.22)
			OsuImage.rectangle(renderer.skin_graphics, lane_xs[column] - lane_widths[column] / 2, hit_y - 5,
				lane_widths[column], 10)
		end
	end
end

return OsuManiaKeyRenderer
