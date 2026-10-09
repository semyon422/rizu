local class = require("class")
local OsuImage = require("rizu.skin.osu.OsuImage")

local lg = love.graphics
local HOLD_COLOR = {1, 0.78, 0.2, 1}
local HEAD_COLOR = {0.25, 0.72, 1, 1}

---@class rizu.skin.osu.mania.OsuManiaNoteRenderer
---@operator call: rizu.skin.osu.mania.OsuManiaNoteRenderer
---@field time number
local OsuManiaNoteRenderer = class()

function OsuManiaNoteRenderer:new()
	self.time = 0
end

function OsuManiaNoteRenderer:update(dt)
	self.time = self.time + math.max(dt, 0)
end

---@param graphics rizu.skin.osu.OsuSkinGraphics
---@param image rizu.skin.osu.OsuSkinGraphics.Image
---@param x number
---@param y number
---@param width number
---@param height number
---@param flip boolean
local function draw_image_rect(graphics, image, x, y, width, height, flip)
	if not image.texture and graphics.batch then graphics.batch:flush() end
	local image_width, image_height = OsuImage.dimensions(image)
	if image_width <= 0 or image_height <= 0 then return end
	local scale_x, scale_y = width / image_width, height / image_height
	lg.setColor(1, 1, 1, 1)
	if flip then OsuImage.draw(image, x, y + height, 0, scale_x, -scale_y)
	else OsuImage.draw(image, x, y, 0, scale_x, scale_y) end
end

---@param graphics rizu.skin.osu.OsuSkinGraphics
---@param image rizu.skin.osu.OsuSkinGraphics.Image
---@param x number
---@param y number
---@param width number
---@param height number
---@param flip boolean
---@param style "repeat_top"|"repeat_bottom"|"repeat_top_and_bottom"
local function draw_repeated_image_rect(graphics, image, x, y, width, height, flip, style)
	local image_width, image_height = OsuImage.dimensions(image)
	if image_width <= 0 or image_height <= 0 or width <= 0 or height <= 0 then return end

	-- A one-pixel body (the common osu! `lnmid` asset) is already uniform
	-- along its repeated axis. Stretch it once instead of adding one sprite per
	-- source pixel. With a 255x1 body, a normal hold could otherwise enqueue
	-- thousands of sprites every frame.
	if image_height == 1 then
		draw_image_rect(graphics, image, x, y, width, height, flip)
		return
	end

	local texture = image.texture and image.texture or image
	local scale = width / image_width
	local source_height = height / scale
	local source_y = style == "repeat_top" and image_height - source_height
		or style == "repeat_top_and_bottom" and (image_height - source_height) / 2
		or 0
	local remaining = source_height ---@type number
	local destination_y = flip and height or 0
	local source_position = source_y ---@type number
	lg.setColor(1, 1, 1, 1)
	while remaining > 0 do
		local wrapped_y = source_position % image_height ---@type number
		local segment_height = math.min(remaining, image_height - wrapped_y) ---@type number
		local destination_height = segment_height * scale
		local qx, qy, density = 0, 0, 1
		local texture_width, texture_height = image_width, image_height
		local draw_scale = scale
		if image.texture then
			qx, qy = image.quad:getViewport()
			density = image.density
			texture_width, texture_height = texture:getDimensions()
			draw_scale = scale / density
		elseif texture.getPixelDimensions then
			texture_width, texture_height = texture:getPixelDimensions()
			density = texture_width / image_width
		end
		local quad = assert(graphics.repeated_quad, "load hold Quad before drawing")
		quad:setViewport(qx, qy + wrapped_y * density, image_width * density,
			segment_height * density, texture_width, texture_height)
		if flip then destination_y = destination_y - destination_height end
		if image.texture then
			image.batch:add(texture, quad, x, y + destination_y + (flip and destination_height or 0),
				0, draw_scale, flip and -draw_scale or draw_scale, 0, 0)
		else
			if graphics.batch then graphics.batch:flush() end
			lg.draw(texture, quad, x, y + destination_y + (flip and destination_height or 0),
				0, draw_scale, flip and -draw_scale or draw_scale)
		end
		if not flip then destination_y = destination_y + destination_height end
		source_position = source_position + segment_height
		remaining = remaining - segment_height
	end
end

---@param graphics rizu.skin.osu.OsuSkinGraphics
---@param image rizu.skin.osu.OsuSkinGraphics.Image
---@param x number
---@param y number
---@param target_width number
---@param target_height number
---@param flip boolean
---@param upside_down boolean
local function draw_note_head(graphics, image, x, y, target_width, target_height, flip, upside_down)
	if not image.texture and graphics.batch then graphics.batch:flush() end
	local image_width, image_height = OsuImage.dimensions(image)
	if image_width <= 0 or image_height <= 0 then return end
	local scale_x, scale_y = target_width / image_width, target_height / image_height
	lg.setColor(1, 1, 1, 1)
	if upside_down then
		if flip then
			OsuImage.draw(image, x, y, 0, scale_x, -scale_y, image_width / 2, image_height)
		else
			OsuImage.draw(image, x, y, 0, scale_x, scale_y, image_width / 2, 0)
		end
	elseif flip then
		OsuImage.draw(image, x, y, 0, scale_x, -scale_y, image_width / 2, 0)
	else
		OsuImage.draw(image, x, y, 0, scale_x, scale_y, image_width / 2, image_height)
	end
end

---@param renderer rizu.skin.osu.OsuManiaRenderer
---@param notes {column: integer, long_note: boolean, head_y: number, tail_y: number, body_visible: boolean, head_visible: boolean, body_frame: integer?}[]
---@param lane_widths number[]
---@param lane_xs number[]
function OsuManiaNoteRenderer:draw(renderer, notes, lane_widths, lane_xs)
	-- Draw every hold body and tail before any head, preserving note layering.
	for _, note in ipairs(notes) do
		local column = note.column
		if note.long_note and note.body_visible then
			local suffix = renderer:getColumnSuffix(column - 1)
			local body_frames = renderer:getColumnFrames(column - 1, suffix, "L")
			local body = body_frames[note.body_frame or 1] or body_frames[1]
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
					local flip_body = renderer.upside_down
						and renderer:getNoteBodyFlip(column)
					local body_style = renderer.note_body_styles[column] or renderer.default_note_body_style
					if body_style == "stretch" then
						draw_image_rect(renderer.skin_graphics, body, lane_xs[column] - note_width / 2, body_top, note_width,
							body_bottom - body_top, flip_body)
					else
						draw_repeated_image_rect(renderer.skin_graphics, body, lane_xs[column] - note_width / 2, body_top,
							note_width, body_bottom - body_top, flip_body, body_style)
					end
				else
					local color = renderer:getSkinColor("ColourHold", HOLD_COLOR)
					lg.setColor(color[1], color[2], color[3], color[4] * 0.8)
					OsuImage.rectangle(renderer.skin_graphics, lane_xs[column] - note_width * 0.32, body_top,
						note_width * 0.64, body_bottom - body_top)
				end
				if tail_image then
					local _, tail_height = renderer:getNoteDimensions(column, tail_image)
					local tail_top = renderer.upside_down and tail_y or tail_y - tail_height
					draw_image_rect(renderer.skin_graphics, tail_image, lane_xs[column] - note_width / 2, tail_top,
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
				local flip = renderer.upside_down
					and renderer:getNoteHeadFlip(column, note.long_note)
				draw_note_head(renderer.skin_graphics, image, lane_xs[column], note.head_y, note_width, note_height,
					flip, renderer.upside_down)
			else
				local color = renderer:getSkinColor("ColourHold", HEAD_COLOR)
				lg.setColor(color[1], color[2], color[3], color[4])
				OsuImage.rectangle(renderer.skin_graphics, lane_xs[column] - lane_widths[column] / 2,
					note.head_y - 10, lane_widths[column], 10)
			end
		end
	end
end

return OsuManiaNoteRenderer
