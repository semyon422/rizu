local class = require("class")

local lg = love.graphics

---@class rizu.skin.osu.mania.OsuManiaNoteRenderer
---@operator call: rizu.skin.osu.mania.OsuManiaNoteRenderer
local OsuManiaNoteRenderer = class()

function OsuManiaNoteRenderer:update(dt) end

---@param image love.Image
---@param x number
---@param y number
---@param width number
---@param height number
---@param flip boolean
local function draw_image_rect(image, x, y, width, height, flip)
	local image_width, image_height = image:getDimensions()
	if image_width <= 0 or image_height <= 0 then return end
	local scale_x, scale_y = width / image_width, height / image_height
	lg.setColor(1, 1, 1, 1)
	if flip then
		lg.draw(image, x, y + height, 0, scale_x, -scale_y)
	else
		lg.draw(image, x, y, 0, scale_x, scale_y)
	end
end

---@param image love.Image
---@param x number
---@param y number
---@param target_width number
---@param target_height number
---@param flip boolean
---@param upside_down boolean
local function draw_note_head(image, x, y, target_width, target_height, flip, upside_down)
	local image_width, image_height = image:getDimensions()
	if image_width <= 0 or image_height <= 0 then return end
	local scale_x, scale_y = target_width / image_width, target_height / image_height
	lg.setColor(1, 1, 1, 1)
	if upside_down then
		if flip then
			lg.draw(image, x, y, 0, scale_x, -scale_y, image_width / 2, image_height)
		else
			lg.draw(image, x, y, 0, scale_x, scale_y, image_width / 2, 0)
		end
	elseif flip then
		lg.draw(image, x, y, 0, scale_x, -scale_y, image_width / 2, 0)
	else
		lg.draw(image, x, y, 0, scale_x, scale_y, image_width / 2, image_height)
	end
end

---@param renderer rizu.skin.osu.OsuManiaRenderer
---@param notes {column: integer, long_note: boolean, head_y: number, tail_y: number, body_visible: boolean, head_visible: boolean}[]
---@param lane_widths number[]
---@param lane_xs number[]
function OsuManiaNoteRenderer:draw(renderer, notes, lane_widths, lane_xs)
	-- Draw every hold body and tail before any head, preserving note layering.
	for _, note in ipairs(notes) do
		local column = note.column
		if note.long_note and note.body_visible then
			local suffix = renderer:getColumnSuffix(column - 1)
			local body = renderer:getColumnImage(column - 1, suffix, "L")
			local head_image = renderer:getColumnImage(column - 1, suffix, "H")
			local tail_image = renderer:getColumnImage(column - 1, suffix, "T")
			local head_y, tail_y = note.head_y, note.tail_y
			local top, bottom = math.min(head_y, tail_y), math.max(head_y, tail_y)
			if bottom > top then
				local note_width = lane_widths[column]
				local head_height = note_width
				if head_image then
					local _, image_height = renderer:getNoteDimensions(column, head_image)
					head_height = image_height
				end

				local body_offset = (renderer.upside_down and 1 or -1) * head_height / 2
				local body_top = top + body_offset
				local body_bottom = bottom + body_offset
				if body then
					local flip_key = "NoteFlipWhenUpsideDown" .. (column - 1) .. "L"
					local flip_body = renderer.upside_down
						and renderer:getBoolean(flip_key, renderer.note_flip)
					draw_image_rect(body, lane_xs[column] - note_width / 2, body_top, note_width,
						body_bottom - body_top, flip_body)
				else
					local color = renderer:getSkinColor("ColourHold", {1, 0.78, 0.2, 1})
					lg.setColor(color[1], color[2], color[3], color[4] * 0.8)
					lg.rectangle("fill", lane_xs[column] - note_width * 0.32, body_top,
						note_width * 0.64, body_bottom - body_top)
				end
				if tail_image then
					local _, tail_height = renderer:getNoteDimensions(column, tail_image)
					local tail_top = renderer.upside_down and tail_y or tail_y - tail_height
					draw_image_rect(tail_image, lane_xs[column] - note_width / 2, tail_top,
						note_width, tail_height, not renderer.upside_down)
				end
			end
		end
	end

	for _, note in ipairs(notes) do
		if note.head_visible then
			local column = note.column
			local suffix = renderer:getColumnSuffix(column - 1)
			local postfix = note.long_note and "H" or ""
			local image = renderer:getColumnImage(column - 1, suffix, postfix)
			if image then
				local note_width, note_height = renderer:getNoteDimensions(column, image)
				local flip_key = "NoteFlipWhenUpsideDown" .. (column - 1) .. postfix
				local flip = renderer.upside_down
					and renderer:getBoolean(flip_key, renderer.note_flip)
				draw_note_head(image, lane_xs[column], note.head_y, note_width, note_height,
					flip, renderer.upside_down)
			else
				local color = renderer:getSkinColor("ColourHold", {0.25, 0.72, 1, 1})
				lg.setColor(color[1], color[2], color[3], color[4])
				lg.rectangle("fill", lane_xs[column] - lane_widths[column] / 2, note.head_y - 10,
					lane_widths[column], 10)
			end
		end
	end
end

return OsuManiaNoteRenderer
