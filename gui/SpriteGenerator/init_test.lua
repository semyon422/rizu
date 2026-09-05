local AtlasImage = require("gui.AtlasImage")
local SpriteGenerator = require("gui.SpriteGenerator.SpriteGenerator")

local test = {}
local old_love = love

local FakeImageData = {}
FakeImageData.__index = FakeImageData

function FakeImageData:new(width, height)
	return setmetatable({width = width, height = height, pixels = {}}, self)
end

function FakeImageData:getDimensions()
	return self.width, self.height
end

function FakeImageData:setPixel(x, y, red, green, blue, alpha)
	self.pixels[x + y * self.width] = {red, green, blue, alpha}
end

function FakeImageData:paste() end

local function fakeTexture(width, height)
	return {
		getWidth = function() return width end,
		getHeight = function() return height end,
		getDimensions = function() return width, height end,
		setFilter = function() end,
		setWrap = function() end,
		release = function() end,
	}
end

local function stubLove()
	local sends = {}
	local canvases = {}
	local active_canvas
	local draw_count = 0
	local gradient_data
	love = {
		image = {
			newImageData = function(width, height)
				local image_data = FakeImageData:new(width, height)
				if height == 1 and width > 2 then
					gradient_data = image_data
				end
				return image_data
			end,
		},
		graphics = {
			newShader = function()
				return {
					send = function(_, name, ...) sends[name] = {...} end,
					release = function() end,
				}
			end,
			newCanvas = function(width, height)
				local canvas = fakeTexture(width, height)
				canvases[#canvases + 1] = canvas
				return canvas
			end,
			readbackTexture = function(texture)
				assert(texture ~= active_canvas, "cannot read back an active render target")
				return FakeImageData:new(texture:getDimensions())
			end,
			newImage = function(data) return fakeTexture(data:getDimensions()) end,
			newQuad = function(x, y, width, height, texture_width, texture_height)
				return {
					getViewport = function() return x, y, width, height end,
					release = function() end,
					texture_width = texture_width,
					texture_height = texture_height,
				}
			end,
			push = function() end,
			pop = function() end,
			origin = function() end,
			setColor = function() end,
			setBlendMode = function() end,
			setShader = function() end,
			setCanvas = function(target) active_canvas = target end,
			clear = function() end,
			draw = function() draw_count = draw_count + 1 end,
		},
	}
	return sends, function() return draw_count end, function() return gradient_data end
end

---@param t testing.T
function test.generates_layered_atlas_images(t)
	local sends, getDrawCount, getGradientData = stubLove()
	local atlases, sprites, nine_slices = SpriteGenerator({
		button = {
			width = 40,
			height = 20,
			border_radius = 5,
			rounding_power = 4,
			slice = 5,
			stroke = {
				width = {left = 1, top = 2, right = 3, bottom = 4},
				color = {0.5, 0.5, 0.5, 0.75},
			},
			fills = {
				{type = "color", color = {0.1, 0.2, 0.3, 1}},
				{
					type = "linear_gradient",
					angle = 90,
					stops = {
						{offset = 0, color = {1, 0, 0, 1}},
						{offset = 0.25, color = {0, 1, 0, 0.75}},
						{offset = 1, color = {0, 0, 1, 0.5}},
					},
				},
			},
		},
	})
	love = old_love

	t:eq(#atlases, 1)
	t:assert(AtlasImage * sprites.button)
	t:eq(sprites.button:getWidth(), 40)
	t:eq(sprites.button:getHeight(), 20)
	t:eq(sends.u_radius[1], 5)
	t:eq(sends.u_rounding_power[1], 4)
	t:tdeq(sends.u_stroke_width[1], {1, 2, 3, 4})
	t:tdeq(sends.u_stroke_color[1], {0.5, 0.5, 0.5, 0.75})
	t:eq(sends.u_uniform_stroke[1], 0)
	t:aeq(sends.u_gradient_direction[1][1], 0, 1e-9)
	t:aeq(sends.u_gradient_direction[1][2], 1, 1e-9)
	t:eq(getDrawCount(), 3)
	t:eq(getGradientData().width, 256)
	t:eq(#nine_slices.button, 9)
	t:eq(nine_slices.button[1]:getWidth(), 5)
	t:eq(nine_slices.button[2]:getWidth(), 30)
	t:eq(nine_slices.button[5]:getHeight(), 10)
	t:eq(nine_slices.button[9]:getWidth(), 5)
	t:eq(nine_slices.button[1].atlas, sprites.button.atlas)
end

---@param t testing.T
function test.interpolates_gradient_stops_with_premultiplied_color(t)
	local _, _, getGradientData = stubLove()
	SpriteGenerator({
		gradient = {
			width = 256,
			height = 8,
			fills = {{
				type = "linear_gradient",
				angle = 0,
				stops = {
					{offset = 0, color = {1, 0, 0, 1}},
					{offset = 0.5, color = {0, 1, 0, 0.5}},
					{offset = 1, color = {0, 0, 1, 0}},
				},
			}},
		},
	})
	love = old_love

	local pixels = getGradientData().pixels
	t:tdeq(pixels[0], {1, 0, 0, 1})
	t:aeq(pixels[255][1], 0, 1e-9)
	t:aeq(pixels[255][2], 0, 1e-9)
	t:aeq(pixels[255][3], 0, 1e-9)
	t:aeq(pixels[255][4], 0, 1e-9)
end

---@param t testing.T
function test.rejects_invalid_definition_before_allocating_graphics(t)
	local shader_created = false
	love = {graphics = {newShader = function() shader_created = true end}}
	local err = t:has_error(function()
		SpriteGenerator({
			button = {
				width = 20,
				height = 10,
				border_radius = 6,
				fills = {{type = "color", color = {1, 1, 1}}},
			},
		})
	end)
	love = old_love

	t:eq(shader_created, false)
	t:eq(err, "sprite `button` border_radius cannot exceed half the shortest side")
end

---@param t testing.T
function test.rejects_unordered_gradient_stops(t)
	love = {graphics = {newShader = function() error("shader should not be created") end}}
	local err = t:has_error(function()
		SpriteGenerator({
			panel = {
				width = 20,
				height = 20,
				fills = {{
					type = "linear_gradient",
					angle = 0,
					stops = {
						{offset = 0.8, color = {1, 1, 1}},
						{offset = 0.2, color = {0, 0, 0}},
					},
				}},
			},
		})
	end)
	love = old_love

	t:eq(err, "sprite `panel` fills[1].stops must be ordered by offset")
end

---@param t testing.T
function test.rejects_slice_smaller_than_radius(t)
	love = {graphics = {newShader = function() error("shader should not be created") end}}
	local err = t:has_error(function()
		SpriteGenerator({
			panel = {
				width = 20,
				height = 20,
				border_radius = 5,
				slice = 4,
				fills = {{type = "color", color = {1, 1, 1}}},
			},
		})
	end)
	love = old_love

	t:eq(err, "sprite `panel` slice must be at least border_radius")
end

---@param t testing.T
function test.marks_uniform_stroke_for_curved_corner_rendering(t)
	local sends = stubLove()
	SpriteGenerator({
		panel = {
			width = 20,
			height = 20,
			border_radius = 5,
			fills = {{type = "color", color = {1, 1, 1}}},
			stroke = {width = 1, color = {1, 1, 1}},
		},
	})
	love = old_love

	t:eq(sends.u_uniform_stroke[1], 1)
end

return test
