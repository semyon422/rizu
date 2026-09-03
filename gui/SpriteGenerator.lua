local ImageAtlasPacker = require("gui.packer.ImageAtlasPacker")

---@alias gui.SpriteGenerator.Color [number, number, number, number?]

---@class gui.SpriteGenerator.LinearGradient
---@field angle number 0 is left-to-right; 90 is top-to-bottom.
---@field colors [gui.SpriteGenerator.Color, gui.SpriteGenerator.Color]

---@class gui.SpriteGenerator.Definition
---@field width integer
---@field height integer
---@field border_radius number?
---@field linear_gradient gui.SpriteGenerator.LinearGradient

local shader_code = [[
extern vec2 u_size;
extern float u_radius;
extern vec2 u_gradient_direction;
extern vec4 u_start_color;
extern vec4 u_end_color;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec2 center = u_size * 0.5;
    vec2 point = screen_coords - center;
    vec2 rounded = abs(point) - (center - vec2(u_radius));
    float distance = length(max(rounded, vec2(0.0))) + min(max(rounded.x, rounded.y), 0.0) - u_radius;
    float alpha = 1.0 - smoothstep(-0.5, 0.5, distance);

    float span = dot(abs(u_gradient_direction), u_size);
    float gradient = clamp(dot(point, u_gradient_direction) / span + 0.5, 0.0, 1.0);
    vec4 gradient_color = mix(u_start_color, u_end_color, gradient);
    return vec4(gradient_color.rgb, gradient_color.a * alpha) * color;
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

---@param definitions {[string]: gui.SpriteGenerator.Definition}
---@return love.Image[] atlases
---@return {[string]: gui.AtlasImage} sprites
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
			shader:send("u_gradient_direction", {math.cos(angle), math.sin(angle)})
			shader:send("u_start_color", normalizeColor(definition.linear_gradient.colors[1]))
			shader:send("u_end_color", normalizeColor(definition.linear_gradient.colors[2]))
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

	return ImageAtlasPacker():pack(image_datas)
end

return setmetatable(SpriteGenerator, {
	__call = function(_, definitions)
		return SpriteGenerator.generate(definitions)
	end,
})
