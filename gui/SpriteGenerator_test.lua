local AtlasImage = require("gui.AtlasImage")
local SpriteGenerator = require("gui.SpriteGenerator")

local test = {}
local old_love = love

local FakeImageData = {}
FakeImageData.__index = FakeImageData

function FakeImageData:new(width, height)
	return setmetatable({width = width, height = height}, self)
end

function FakeImageData:getDimensions()
	return self.width, self.height
end

function FakeImageData:paste() end

local function fakeTexture(width, height)
	return {
		getWidth = function() return width end,
		getHeight = function() return height end,
		getDimensions = function() return width, height end,
		setWrap = function() end,
	}
end

local function stubLove()
	local sends = {}
	local canvas
	local active_canvas
	love = {
		image = {
			newImageData = function(width, height) return FakeImageData:new(width, height) end,
		},
		graphics = {
			newShader = function()
				return {
					send = function(_, name, ...) sends[name] = {...} end,
					release = function() end,
				}
			end,
			newCanvas = function(width, height)
				canvas = fakeTexture(width, height)
				canvas.release = function() end
				return canvas
			end,
			readbackTexture = function(texture)
				assert(texture ~= active_canvas, "cannot read back an active render target")
				return FakeImageData:new(texture:getDimensions())
			end,
			newImage = function(image_data) return fakeTexture(image_data:getDimensions()) end,
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
			rectangle = function() end,
		},
	}
	return sends
end

---@param t testing.T
function test.generates_atlas_images(t)
	local sends = stubLove()
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
			linear_gradient = {
				angle = 90,
				colors = {{1, 0, 0, 1}, {0, 0, 1, 0.5}},
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
	t:aeq(sends.u_gradient_direction[1][1], 0, 1e-9)
	t:aeq(sends.u_gradient_direction[1][2], 1, 1e-9)
	t:eq(#nine_slices.button, 9)
	t:eq(nine_slices.button[1]:getWidth(), 5)
	t:eq(nine_slices.button[2]:getWidth(), 30)
	t:eq(nine_slices.button[5]:getHeight(), 10)
	t:eq(nine_slices.button[9]:getWidth(), 5)
	t:eq(nine_slices.button[1].atlas, sprites.button.atlas)
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
				linear_gradient = {angle = 90, colors = {{1, 1, 1}, {0, 0, 0}}},
			},
		})
	end)
	love = old_love

	t:eq(shader_created, false)
	t:eq(err, "sprite `button` border_radius cannot exceed half the shortest side")
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
				linear_gradient = {angle = 0, colors = {{1, 1, 1}, {1, 1, 1}}},
			},
		})
	end)
	love = old_love

	t:eq(err, "sprite `panel` slice must be at least border_radius")
end

return test
