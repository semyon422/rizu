local ImageAtlasPacker = require("gui.packer.ImageAtlasPacker")
local AtlasImage = require("gui.AtlasImage")

local test = {}
local old_love = love

local FakeImageData = {}
FakeImageData.__index = FakeImageData

---@param width integer
---@param height integer
---@return table
function FakeImageData:new(width, height)
	return setmetatable({width = width, height = height, pastes = {}}, self)
end

function FakeImageData:getDimensions()
	return self.width, self.height
end

function FakeImageData:paste(...)
	self.pastes[#self.pastes + 1] = {...}
end

local function fakeImage(width, height)
	return {
		width = width,
		height = height,
		getWidth = function(self) return self.width end,
		getHeight = function(self) return self.height end,
		getDimensions = function(self) return self.width, self.height end,
		setWrap = function() end,
		release = function(self) self.released = true end,
	}
end

local function stubLove()
	love = {
		image = {
			newImageData = function(width, height)
				return FakeImageData:new(width, height)
			end,
		},
		graphics = {
			newImage = function(image_data) return fakeImage(image_data.width, image_data.height) end,
			newQuad = function(x, y, width, height, texture_width, texture_height)
				return {
					x = x, y = y, width = width, height = height,
					texture_width = texture_width, texture_height = texture_height,
					getViewport = function(self) return self.x, self.y, self.width, self.height end,
					release = function(self) self.released = true end,
				}
			end,
		},
	}
end

---@param t testing.T
function test.creates_atlas_sprite(t)
	stubLove()
	local packer = ImageAtlasPacker()
	packer.max_atlas_width = 16
	packer.max_atlas_height = 16
	local atlases, sprites = packer:pack({a = FakeImageData:new(4, 5)})
	love = old_love

	t:eq(#atlases, 1)
	t:eq(atlases[1]:getWidth(), 6)
	t:eq(atlases[1]:getHeight(), 7)
	t:assert(AtlasImage * sprites.a)
	t:eq(sprites.a:getWidth(), 4)
	t:eq(sprites.a:getHeight(), 5)
	t:eq(sprites.a.quad.texture_width, 6)
	t:eq(sprites.a.quad.texture_height, 7)
end

---@param t testing.T
function test.creates_multiple_atlases(t)
	stubLove()
	local packer = ImageAtlasPacker()
	packer.max_atlas_width = 8
	packer.max_atlas_height = 8
	local atlases, sprites = packer:pack({
		a = FakeImageData:new(6, 6),
		b = FakeImageData:new(6, 6),
	})
	love = old_love

	t:eq(#atlases, 2)
	for _, atlas in ipairs(atlases) do
		t:eq(atlas:getWidth(), 8)
		t:eq(atlas:getHeight(), 8)
	end
	t:assert(AtlasImage * sprites.a)
	t:assert(AtlasImage * sprites.b)
	t:ne(sprites.a.atlas, sprites.b.atlas)
end

---@param t testing.T
function test.large_image_is_packed(t)
	stubLove()
	local packer = ImageAtlasPacker()
	local large = FakeImageData:new(1537, 2)
	local atlases, sprites = packer:pack({large = large})
	love = old_love

	t:eq(#atlases, 1)
	t:assert(AtlasImage * sprites.large)
	t:eq(sprites.large:getWidth(), 1537)
	t:eq(sprites.large:getHeight(), 2)
end

---@param t testing.T
function test.image_larger_than_atlas_fails(t)
	stubLove()
	local packer = ImageAtlasPacker()
	packer.max_atlas_width = 16
	packer.max_atlas_height = 16
	local err = t:has_error(function()
		packer:pack({large = FakeImageData:new(15, 2)})
	end)
	love = old_love

	t:eq(err, "sprite `large` does not fit in an atlas")
end

return test
