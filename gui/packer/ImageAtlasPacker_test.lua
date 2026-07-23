local ImageAtlasPacker = require("gui.packer.ImageAtlasPacker")

local test = {}

local old_love = love

---@class gui.packer._FakeImageData
---@field width integer
---@field height integer
---@field format string?
---@field pastes table[]
local FakeImageData = {}
FakeImageData.__index = FakeImageData

---@param width integer
---@param height integer
---@param format string?
---@return gui.packer._FakeImageData
function FakeImageData:new(width, height, format)
	return setmetatable({
		width = width,
		height = height,
		format = format,
		pastes = {},
	}, self)
end

function FakeImageData:getDimensions()
	return self.width, self.height
end

function FakeImageData:getFormat()
	return self.format
end

function FakeImageData:paste(source, dx, dy, sx, sy, sw, sh)
	self.pastes[#self.pastes + 1] = {
		source = source,
		dx = dx,
		dy = dy,
		sx = sx,
		sy = sy,
		sw = sw,
		sh = sh,
	}
end

local function stubLove()
	love = {
		image = {
			newImageData = function(width, height, format)
				return FakeImageData:new(width, height, format)
			end,
		},
		graphics = {
			newQuad = function(x, y, w, h, tw, th)
				return {
					x = x,
					y = y,
					w = w,
					h = h,
					tw = tw,
					th = th,
				}
			end,
		},
	}
end

local function restoreLove()
	love = old_love
end

---@param t testing.T
function test.pack_builds_atlas_and_named_quads(t)
	stubLove()

	local packer = ImageAtlasPacker()
	local hero = FakeImageData:new(4, 4, "rgba8")
	local coin = FakeImageData:new(2, 3, "rgba8")
	local cursor = FakeImageData:new(3, 2, "rgba8")

	local atlas, quads = packer:pack({
		hero = hero,
		coin = coin,
		cursor = cursor,
	})

	restoreLove()

	t:eq(atlas.width, 6)
	t:eq(atlas.height, 15)
	t:eq(atlas.format, "rgba8")
	t:eq(#atlas.pastes, 27)

	t:eq(quads.hero.x, 1)
	t:eq(quads.hero.y, 1)
	t:eq(quads.hero.w, 4)
	t:eq(quads.hero.h, 4)
	t:eq(quads.hero.tw, 6)
	t:eq(quads.hero.th, 15)

	t:eq(quads.coin.x, 1)
	t:eq(quads.coin.y, 7)
	t:eq(quads.coin.w, 2)
	t:eq(quads.coin.h, 3)

	t:eq(quads.cursor.x, 1)
	t:eq(quads.cursor.y, 12)
	t:eq(quads.cursor.w, 3)
	t:eq(quads.cursor.h, 2)
end

---@param t testing.T
function test.pack_extrudes_1px_border_from_sprite_edges(t)
	stubLove()

	local packer = ImageAtlasPacker()
	local sprite = FakeImageData:new(2, 3, "rgba8")

	local atlas = packer:pack({
		sprite = sprite,
	})

	restoreLove()

	t:eq(atlas.width, 4)
	t:eq(atlas.height, 5)
	t:eq(#atlas.pastes, 9)

	local body = atlas.pastes[1]
	t:eq(body.dx, 1)
	t:eq(body.dy, 1)
	t:eq(body.sx, 0)
	t:eq(body.sy, 0)
	t:eq(body.sw, 2)
	t:eq(body.sh, 3)

	local left = atlas.pastes[2]
	t:eq(left.dx, 0)
	t:eq(left.dy, 1)
	t:eq(left.sx, 0)
	t:eq(left.sy, 0)
	t:eq(left.sw, 1)
	t:eq(left.sh, 3)

	local right = atlas.pastes[3]
	t:eq(right.dx, 3)
	t:eq(right.dy, 1)
	t:eq(right.sx, 1)
	t:eq(right.sy, 0)
	t:eq(right.sw, 1)
	t:eq(right.sh, 3)

	local top = atlas.pastes[4]
	t:eq(top.dx, 1)
	t:eq(top.dy, 0)
	t:eq(top.sx, 0)
	t:eq(top.sy, 0)
	t:eq(top.sw, 2)
	t:eq(top.sh, 1)

	local bottom = atlas.pastes[5]
	t:eq(bottom.dx, 1)
	t:eq(bottom.dy, 4)
	t:eq(bottom.sx, 0)
	t:eq(bottom.sy, 2)
	t:eq(bottom.sw, 2)
	t:eq(bottom.sh, 1)

	local top_left = atlas.pastes[6]
	t:eq(top_left.dx, 0)
	t:eq(top_left.dy, 0)
	t:eq(top_left.sx, 0)
	t:eq(top_left.sy, 0)
	t:eq(top_left.sw, 1)
	t:eq(top_left.sh, 1)

	local top_right = atlas.pastes[7]
	t:eq(top_right.dx, 3)
	t:eq(top_right.dy, 0)
	t:eq(top_right.sx, 1)
	t:eq(top_right.sy, 0)
	t:eq(top_right.sw, 1)
	t:eq(top_right.sh, 1)

	local bottom_left = atlas.pastes[8]
	t:eq(bottom_left.dx, 0)
	t:eq(bottom_left.dy, 4)
	t:eq(bottom_left.sx, 0)
	t:eq(bottom_left.sy, 2)
	t:eq(bottom_left.sw, 1)
	t:eq(bottom_left.sh, 1)

	local bottom_right = atlas.pastes[9]
	t:eq(bottom_right.dx, 3)
	t:eq(bottom_right.dy, 4)
	t:eq(bottom_right.sx, 1)
	t:eq(bottom_right.sy, 2)
	t:eq(bottom_right.sw, 1)
	t:eq(bottom_right.sh, 1)
end

---@param t testing.T
function test.pack_returns_minimal_empty_atlas_for_empty_input(t)
	stubLove()

	local packer = ImageAtlasPacker()
	local atlas, quads = packer:pack({})

	restoreLove()

	t:eq(atlas.width, 1)
	t:eq(atlas.height, 1)
	t:eq(#atlas.pastes, 0)
	t:eq(next(quads), nil)
end

---@param t testing.T
function test.pack_rejects_mixed_formats(t)
	stubLove()

	local packer = ImageAtlasPacker()
	local ok, err = pcall(function()
		packer:pack({
			a = FakeImageData:new(4, 4, "rgba8"),
			b = FakeImageData:new(2, 2, "r8"),
		})
	end)

	restoreLove()

	t:assert(not ok)
	t:assert(tostring(err):match("same ImageData format"))
end

return test
