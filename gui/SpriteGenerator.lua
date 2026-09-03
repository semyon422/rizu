local ImageAtlasPacker = require("gui.packer.ImageAtlasPacker")
local AtlasImage = require("gui.AtlasImage")

---@alias gui.SpriteGenerator.Color [number, number, number, number?]

---@class gui.SpriteGenerator.LinearGradient
---@field angle number 0 is left-to-right; 90 is top-to-bottom.
---@field colors [gui.SpriteGenerator.Color, gui.SpriteGenerator.Color]

---@class gui.SpriteGenerator.Definition
---@field width integer
---@field height integer
---@field border_radius number?
---@field rounding_power number? 2 is circular; larger values produce squarer corners.
---@field linear_gradient gui.SpriteGenerator.LinearGradient
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

local shader_code = [[
extern vec2 u_size;
extern float u_radius;
extern float u_rounding_power;
extern vec2 u_gradient_direction;
extern vec4 u_start_color;
extern vec4 u_end_color;
extern vec4 u_stroke_width;
extern vec4 u_stroke_color;

float roundedRectangleDistance(vec2 point, vec2 center, vec2 half_size, float radius) {
    vec2 rounded = abs(point - center) - (half_size - vec2(radius));
    vec2 outside = max(rounded, vec2(0.0));
    float corner_distance = pow(pow(outside.x, u_rounding_power) + pow(outside.y, u_rounding_power), 1.0 / u_rounding_power);
    return corner_distance + min(max(rounded.x, rounded.y), 0.0) - radius;
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
    float stroke_alpha = max(max(left_stroke, top_stroke), max(right_stroke, bottom_stroke)) * outer_alpha;

    float span = dot(abs(u_gradient_direction), u_size);
    float gradient = clamp(dot(point - center, u_gradient_direction) / span + 0.5, 0.0, 1.0);
    vec4 gradient_color = mix(u_start_color, u_end_color, gradient);
    float fill_alpha = gradient_color.a * outer_alpha;
    float border_alpha = u_stroke_color.a * stroke_alpha;
    float alpha = border_alpha + fill_alpha * (1.0 - border_alpha);
    vec3 rgb = (u_stroke_color.rgb * border_alpha + gradient_color.rgb * fill_alpha * (1.0 - border_alpha)) / max(alpha, 0.0001);
    return vec4(rgb, alpha) * color;
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

	local gradient = definition.linear_gradient
	assert(type(gradient) == "table", prefix .. " linear_gradient must be a table")
	assert(isFinite(gradient.angle), prefix .. " linear_gradient.angle must be finite")
	assert(type(gradient.colors) == "table" and #gradient.colors == 2,
		prefix .. " linear_gradient.colors must contain exactly 2 colors")
	validateColor(gradient.colors[1], prefix .. " linear_gradient.colors[1]")
	validateColor(gradient.colors[2], prefix .. " linear_gradient.colors[2]")
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

	local shader = love.graphics.newShader(shader_code)
	local image_datas = {} ---@type {[string]: love.ImageData}
	local active_canvas ---@type love.Canvas?
	love.graphics.push("all")
	local ok, err = xpcall(function()
		love.graphics.origin()
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.setBlendMode("replace")
		love.graphics.setShader(shader)

		for name, definition in pairs(definitions) do
			active_canvas = love.graphics.newCanvas(definition.width, definition.height)
			love.graphics.setCanvas(active_canvas)
			love.graphics.clear(0, 0, 0, 0)

			local angle = math.rad(definition.linear_gradient.angle)
			shader:send("u_size", {definition.width, definition.height})
			shader:send("u_radius", definition.border_radius or 0)
			shader:send("u_rounding_power", definition.rounding_power or 2)
			shader:send("u_gradient_direction", {math.cos(angle), math.sin(angle)})
			shader:send("u_start_color", normalizeColor(definition.linear_gradient.colors[1]))
			shader:send("u_end_color", normalizeColor(definition.linear_gradient.colors[2]))
			shader:send("u_stroke_width", normalizeStrokeWidths(definition.stroke))
			shader:send("u_stroke_color", normalizeColor(definition.stroke and definition.stroke.color or {0, 0, 0, 0}))
			love.graphics.rectangle("fill", 0, 0, definition.width, definition.height)
			love.graphics.setCanvas()
			image_datas[name] = love.graphics.readbackTexture(active_canvas)
			active_canvas:release()
			active_canvas = nil
		end
	end, debug.traceback)
	love.graphics.pop()
	if active_canvas then
		active_canvas:release()
	end
	shader:release()
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
