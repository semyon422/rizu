local ImageAtlasPacker = require("gui.packer.ImageAtlasPacker")
local AtlasImage = require("gui.AtlasImage")

---@alias gui.SpriteGenerator.Color [number, number, number, number?]

---@class gui.SpriteGenerator.ColorFill
---@field type "color"
---@field color gui.SpriteGenerator.Color

---@class gui.SpriteGenerator.GradientStop
---@field offset number Position from 0 to 1.
---@field color gui.SpriteGenerator.Color

---@class gui.SpriteGenerator.LinearGradientFill
---@field type "linear_gradient"
---@field angle number 0 is left-to-right; 90 is top-to-bottom.
---@field stops gui.SpriteGenerator.GradientStop[]

---@alias gui.SpriteGenerator.Fill gui.SpriteGenerator.ColorFill|gui.SpriteGenerator.LinearGradientFill

---@class gui.SpriteGenerator.Definition
---@field width integer
---@field height integer
---@field border_radius number?
---@field rounding_power number? 2 is circular; larger values produce squarer corners.
---@field fills gui.SpriteGenerator.Fill[]
---@field slice number? Insets used to create a nine-slice.
---@field stroke gui.SpriteGenerator.Stroke?

---@class gui.SpriteGenerator.StrokeWidths
---@field left number?
---@field top number?
---@field right number?
---@field bottom number?

---@class gui.SpriteGenerator.Stroke
---@field width number|gui.SpriteGenerator.StrokeWidths
---@field color gui.SpriteGenerator.Color

local fill_shader_code = [[
extern vec2 u_size;
extern float u_radius;
extern float u_rounding_power;
extern vec2 u_gradient_direction;
extern Image u_gradient_texture;
extern float u_gradient_width;
extern vec4 u_fill_color;
extern float u_use_gradient;

float roundedRectangleDistance(vec2 point, vec2 center, vec2 half_size, float radius) {
    vec2 rounded = abs(point - center) - (half_size - vec2(radius));
    vec2 outside = max(rounded, vec2(0.0));
    float corner_distance = pow(pow(outside.x, u_rounding_power) + pow(outside.y, u_rounding_power), 1.0 / u_rounding_power);
    return corner_distance + min(max(rounded.x, rounded.y), 0.0) - radius;
}

vec4 sourceOver(vec4 destination, vec4 source_premultiplied) {
    float alpha = source_premultiplied.a + destination.a * (1.0 - source_premultiplied.a);
    vec3 rgb = (source_premultiplied.rgb + destination.rgb * destination.a * (1.0 - source_premultiplied.a)) / max(alpha, 0.0001);
    return vec4(rgb, alpha);
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec2 center = u_size * 0.5;
    float distance = roundedRectangleDistance(screen_coords, center, center, u_radius);
    float mask = 1.0 - smoothstep(-0.5, 0.5, distance);

    float span = max(dot(abs(u_gradient_direction), u_size), 0.0001);
    float gradient = clamp(dot(screen_coords - center, u_gradient_direction) / span + 0.5, 0.0, 1.0);
    float gradient_u = (gradient * (u_gradient_width - 1.0) + 0.5) / u_gradient_width;
    vec4 fill = mix(u_fill_color, Texel(u_gradient_texture, vec2(gradient_u, 0.5)), u_use_gradient);
    fill *= mask;
    return sourceOver(Texel(texture, texture_coords), fill) * color;
}
]]

local stroke_shader_code = [[
extern vec2 u_size;
extern float u_radius;
extern float u_rounding_power;
extern vec4 u_stroke_width;
extern vec4 u_stroke_color;
extern float u_uniform_stroke;

float roundedRectangleDistance(vec2 point, vec2 center, vec2 half_size, float radius) {
    vec2 rounded = abs(point - center) - (half_size - vec2(radius));
    vec2 outside = max(rounded, vec2(0.0));
    float corner_distance = pow(pow(outside.x, u_rounding_power) + pow(outside.y, u_rounding_power), 1.0 / u_rounding_power);
    return corner_distance + min(max(rounded.x, rounded.y), 0.0) - radius;
}

vec4 sourceOver(vec4 destination, vec4 source) {
    float alpha = source.a + destination.a * (1.0 - source.a);
    vec3 rgb = (source.rgb * source.a + destination.rgb * destination.a * (1.0 - source.a)) / max(alpha, 0.0001);
    return vec4(rgb, alpha);
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec2 center = u_size * 0.5;
    vec2 point = screen_coords;
    float outer_distance = roundedRectangleDistance(point, center, center, u_radius);
    float outer_alpha = 1.0 - smoothstep(-0.5, 0.5, outer_distance);

    float left_stroke = 1.0 - smoothstep(u_stroke_width.x - 0.5, u_stroke_width.x + 0.5, point.x);
    float top_stroke = 1.0 - smoothstep(u_stroke_width.y - 0.5, u_stroke_width.y + 0.5, point.y);
    float right_stroke = smoothstep(u_size.x - u_stroke_width.z - 0.5, u_size.x - u_stroke_width.z + 0.5, point.x);
    float bottom_stroke = smoothstep(u_size.y - u_stroke_width.w - 0.5, u_size.y - u_stroke_width.w + 0.5, point.y);
    float side_stroke_alpha = max(max(left_stroke, top_stroke), max(right_stroke, bottom_stroke)) * outer_alpha;

    float uniform_width = u_stroke_width.x;
    vec2 inner_half_size = max(center - vec2(uniform_width), vec2(0.0));
    float inner_radius = max(u_radius - uniform_width, 0.0);
    float inner_distance = roundedRectangleDistance(point, center, inner_half_size, inner_radius);
    float inner_alpha = 1.0 - smoothstep(-0.5, 0.5, inner_distance);
    float uniform_stroke_alpha = max(outer_alpha - inner_alpha, 0.0);
    float stroke_alpha = mix(side_stroke_alpha, uniform_stroke_alpha, u_uniform_stroke);

    vec4 stroke = vec4(u_stroke_color.rgb, u_stroke_color.a * stroke_alpha);
    return sourceOver(Texel(texture, texture_coords), stroke) * color;
}
]]

local SpriteGenerator = {}

---@param value any
---@return boolean
local function isFinite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

---@param color any
---@param field string
local function validateColor(color, field)
	assert(type(color) == "table", field .. " must be a color")
	assert(#color == 3 or #color == 4, field .. " must have 3 or 4 components")
	for i = 1, #color do
		assert(isFinite(color[i]) and color[i] >= 0 and color[i] <= 1,
			("%s component %d must be between 0 and 1"):format(field, i))
	end
end

---@param name string
---@param definition gui.SpriteGenerator.Definition
local function validateDefinition(name, definition)
	local prefix = ("sprite `%s`"):format(name)
	assert(type(definition) == "table", prefix .. " must be a table")
	assert(isFinite(definition.width) and definition.width > 0 and definition.width % 1 == 0,
		prefix .. " width must be a positive integer")
	assert(isFinite(definition.height) and definition.height > 0 and definition.height % 1 == 0,
		prefix .. " height must be a positive integer")

	local radius = definition.border_radius or 0
	assert(isFinite(radius) and radius >= 0, prefix .. " border_radius must be non-negative")
	assert(radius <= math.min(definition.width, definition.height) / 2,
		prefix .. " border_radius cannot exceed half the shortest side")
	local rounding_power = definition.rounding_power or 2
	assert(isFinite(rounding_power) and rounding_power >= 1,
		prefix .. " rounding_power must be at least 1")

	if definition.slice ~= nil then
		assert(isFinite(definition.slice) and definition.slice > 0 and definition.slice % 1 == 0,
			prefix .. " slice must be a positive integer")
		assert(definition.slice >= radius, prefix .. " slice must be at least border_radius")
		assert(definition.slice * 2 < definition.width and definition.slice * 2 < definition.height,
			prefix .. " slice must leave a non-empty center")
	end

	local stroke = definition.stroke
	if stroke ~= nil then
		assert(type(stroke) == "table", prefix .. " stroke must be a table")
		local widths = stroke.width
		if type(widths) == "number" then
			assert(isFinite(widths) and widths >= 0, prefix .. " stroke.width must be non-negative")
		else
			assert(type(widths) == "table", prefix .. " stroke.width must be a number or table")
			---@cast widths gui.SpriteGenerator.StrokeWidths
			for _, side in ipairs({"left", "top", "right", "bottom"}) do
				local width = widths[side] or 0
				assert(isFinite(width) and width >= 0,
					("%s stroke.width.%s must be non-negative"):format(prefix, side))
			end
		end
		local left, top, right, bottom
		if type(widths) == "number" then
			left, top, right, bottom = widths, widths, widths, widths
		else
			left, top, right, bottom = widths.left or 0, widths.top or 0, widths.right or 0, widths.bottom or 0
		end
		assert(left + right < definition.width, prefix .. " horizontal stroke widths must leave a non-empty fill")
		assert(top + bottom < definition.height, prefix .. " vertical stroke widths must leave a non-empty fill")
		validateColor(stroke.color, prefix .. " stroke.color")
	end

	assert(type(definition.fills) == "table" and #definition.fills > 0,
		prefix .. " fills must contain at least one fill")
	for index, fill in ipairs(definition.fills) do
		local fill_prefix = ("%s fills[%d]"):format(prefix, index)
		assert(type(fill) == "table", fill_prefix .. " must be a table")
		if fill.type == "color" then
			validateColor(fill.color, fill_prefix .. ".color")
		elseif fill.type == "linear_gradient" then
			assert(isFinite(fill.angle), fill_prefix .. ".angle must be finite")
			assert(type(fill.stops) == "table" and #fill.stops >= 2,
				fill_prefix .. ".stops must contain at least 2 stops")
			local previous_offset = -math.huge
			for stop_index, stop in ipairs(fill.stops) do
				local stop_prefix = ("%s.stops[%d]"):format(fill_prefix, stop_index)
				assert(type(stop) == "table", stop_prefix .. " must be a table")
				assert(isFinite(stop.offset) and stop.offset >= 0 and stop.offset <= 1,
					stop_prefix .. ".offset must be between 0 and 1")
				assert(stop.offset >= previous_offset, fill_prefix .. ".stops must be ordered by offset")
				validateColor(stop.color, stop_prefix .. ".color")
				previous_offset = stop.offset
			end
		else
			error(fill_prefix .. ".type must be `color` or `linear_gradient`", 0)
		end
	end
end

---@param color gui.SpriteGenerator.Color
---@return [number, number, number, number]
local function normalizeColor(color)
	return {color[1], color[2], color[3], color[4] or 1}
end

---@param stroke gui.SpriteGenerator.Stroke?
---@return [number, number, number, number]
local function normalizeStrokeWidths(stroke)
	if not stroke then
		return {0, 0, 0, 0}
	end
	if type(stroke.width) == "number" then
		return {stroke.width, stroke.width, stroke.width, stroke.width}
	end
	return {
		stroke.width.left or 0,
		stroke.width.top or 0,
		stroke.width.right or 0,
		stroke.width.bottom or 0,
	}
end

---@param stroke gui.SpriteGenerator.Stroke?
---@return number
local function isUniformStroke(stroke)
	if not stroke then
		return 0
	end
	if type(stroke.width) == "number" then
		return 1
	end
	local left = stroke.width.left or 0
	return left == (stroke.width.top or 0)
		and left == (stroke.width.right or 0)
		and left == (stroke.width.bottom or 0)
		and 1 or 0
end

---@param stops gui.SpriteGenerator.GradientStop[]
---@param width integer
---@return love.Image
local function createGradientTexture(stops, width)
	local image_data = love.image.newImageData(width, 1)
	local stop_index = 1
	for x = 0, width - 1 do
		local offset = x / (width - 1)
		while stop_index < #stops - 1 and offset > stops[stop_index + 1].offset do
			stop_index = stop_index + 1
		end
		local first = stops[stop_index]
		local second = stops[stop_index + 1]
		local span = second.offset - first.offset
		local amount = span > 0 and math.max(0, math.min(1, (offset - first.offset) / span)) or 1
		local first_color = normalizeColor(first.color)
		local second_color = normalizeColor(second.color)
		local alpha = first_color[4] + (second_color[4] - first_color[4]) * amount
		local red = first_color[1] * first_color[4] + (second_color[1] * second_color[4] - first_color[1] * first_color[4]) * amount
		local green = first_color[2] * first_color[4] + (second_color[2] * second_color[4] - first_color[2] * first_color[4]) * amount
		local blue = first_color[3] * first_color[4] + (second_color[3] * second_color[4] - first_color[3] * first_color[4]) * amount
		image_data:setPixel(x, 0, red, green, blue, alpha)
	end
	local image = love.graphics.newImage(image_data)
	image:setFilter("linear", "linear")
	image:setWrap("clamp", "clamp")
	return image
end

---@param shader love.Shader
---@param definition gui.SpriteGenerator.Definition
local function sendShape(shader, definition)
	shader:send("u_size", {definition.width, definition.height})
	shader:send("u_radius", definition.border_radius or 0)
	shader:send("u_rounding_power", definition.rounding_power or 2)
end

---@param definitions {[string]: gui.SpriteGenerator.Definition}
---@return love.Image[] atlases
---@return {[string]: gui.AtlasImage} sprites
---@return {[string]: gui.NineSliceSprites} nine_slices
function SpriteGenerator.generate(definitions)
	assert(type(definitions) == "table", "sprite definitions must be a table")
	for name, definition in pairs(definitions) do
		assert(type(name) == "string" and name ~= "", "sprite names must be non-empty strings")
		validateDefinition(name, definition)
	end

	local fill_shader = love.graphics.newShader(fill_shader_code)
	local stroke_shader = love.graphics.newShader(stroke_shader_code)
	local image_datas = {} ---@type {[string]: love.ImageData}
	local active_canvas ---@type love.Canvas?
	local other_canvas ---@type love.Canvas?
	local gradient_texture ---@type love.Image?
	local fallback_gradient_texture = createGradientTexture({
		{offset = 0, color = {0, 0, 0, 0}},
		{offset = 1, color = {0, 0, 0, 0}},
	}, 2)
	love.graphics.push("all")
	local ok, err = xpcall(function()
		love.graphics.origin()
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.setBlendMode("replace")

		for name, definition in pairs(definitions) do
			active_canvas = love.graphics.newCanvas(definition.width, definition.height)
			other_canvas = love.graphics.newCanvas(definition.width, definition.height)
			love.graphics.setCanvas(active_canvas)
			love.graphics.clear(0, 0, 0, 0)
			love.graphics.setShader(fill_shader)
			sendShape(fill_shader, definition)
			fill_shader:send("u_gradient_texture", fallback_gradient_texture)
			fill_shader:send("u_gradient_width", 2)

			for _, fill in ipairs(definition.fills) do
				local ramp_width = math.max(256, definition.width, definition.height)
				if fill.type == "linear_gradient" then
					gradient_texture = createGradientTexture(fill.stops, ramp_width)
					local angle = math.rad(fill.angle)
					fill_shader:send("u_gradient_direction", {math.cos(angle), math.sin(angle)})
					fill_shader:send("u_gradient_texture", gradient_texture)
					fill_shader:send("u_gradient_width", ramp_width)
					fill_shader:send("u_fill_color", {0, 0, 0, 0})
					fill_shader:send("u_use_gradient", 1)
				else
					local color = normalizeColor(fill.color)
					fill_shader:send("u_fill_color", {color[1] * color[4], color[2] * color[4], color[3] * color[4], color[4]})
					fill_shader:send("u_use_gradient", 0)
				end

				love.graphics.setCanvas(other_canvas)
				love.graphics.clear(0, 0, 0, 0)
				love.graphics.draw(active_canvas)
				active_canvas, other_canvas = other_canvas, active_canvas
				if gradient_texture then
					gradient_texture:release()
					gradient_texture = nil
				end
			end

			if definition.stroke then
				love.graphics.setShader(stroke_shader)
				sendShape(stroke_shader, definition)
				stroke_shader:send("u_stroke_width", normalizeStrokeWidths(definition.stroke))
				stroke_shader:send("u_stroke_color", normalizeColor(definition.stroke.color))
				stroke_shader:send("u_uniform_stroke", isUniformStroke(definition.stroke))
				love.graphics.setCanvas(other_canvas)
				love.graphics.clear(0, 0, 0, 0)
				love.graphics.draw(active_canvas)
				active_canvas, other_canvas = other_canvas, active_canvas
			end

			love.graphics.setCanvas()
			image_datas[name] = love.graphics.readbackTexture(active_canvas)
			active_canvas:release()
			other_canvas:release()
			active_canvas, other_canvas = nil, nil
		end
	end, debug.traceback)
	love.graphics.pop()
	if gradient_texture then
		gradient_texture:release()
	end
	if active_canvas then
		active_canvas:release()
	end
	if other_canvas then
		other_canvas:release()
	end
	fill_shader:release()
	stroke_shader:release()
	fallback_gradient_texture:release()
	if not ok then
		error(err, 0)
	end

	local atlases, sprites = ImageAtlasPacker():pack(image_datas)
	local nine_slices = {} ---@type {[string]: gui.NineSliceSprites}
	for name, definition in pairs(definitions) do
		local inset = definition.slice
		if inset then
			local sprite = sprites[name]
			local x, y, width, height = sprite.quad:getViewport()
			local texture_width, texture_height = sprite.atlas:getDimensions()
			local widths = {inset, width - inset * 2, inset}
			local heights = {inset, height - inset * 2, inset}
			local slices = {} ---@type gui.AtlasImage[]
			local slice_y = y
			for row = 1, 3 do
				local slice_x = x
				for column = 1, 3 do
					local quad = love.graphics.newQuad(
						slice_x, slice_y, widths[column], heights[row], texture_width, texture_height
					)
					slices[#slices + 1] = AtlasImage(sprite.atlas, quad)
					slice_x = slice_x + widths[column]
				end
				slice_y = slice_y + heights[row]
			end
			nine_slices[name] = slices --[[@as gui.NineSliceSprites]]
		end
	end

	return atlases, sprites, nine_slices
end

return setmetatable(SpriteGenerator, {
	__call = function(_, definitions)
		return SpriteGenerator.generate(definitions)
	end,
})
