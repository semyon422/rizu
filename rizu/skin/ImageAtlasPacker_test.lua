local ImageAtlasPacker = require("rizu.skin.ImageAtlasPacker")

local test = {}

---@class rizu.skin.ImageAtlasPacker_test.ImageData : love.ImageData
---@field pastes table[]

---@param width integer
---@param height integer
---@return rizu.skin.ImageAtlasPacker_test.ImageData
local function imageData(width, height)
	return {
		getDimensions = function() return width, height end,
		pastes = {},
		---@param self rizu.skin.ImageAtlasPacker_test.ImageData
		paste = function(self, ...)
			self.pastes[#self.pastes + 1] = {...}
		end,
	}
end

-- No graphics module at all: packing must not allocate Images, Quads or Canvases.
---@param packer rizu.skin.ImageAtlasPacker
---@param sources {[string]: love.ImageData}
---@return rizu.skin.ImageAtlasPacker_test.ImageData[]
---@return {[string]: rizu.skin.ImageAtlasPacker.Location}
local function pack(packer, sources)
	local previous_love = love ---@type table?
	love = {image = {newImageData = imageData}}
	local ok, atlases, locations = pcall(packer.pack, packer, sources)
	love = previous_love
	if not ok then
		error(atlases, 0)
	end
	return atlases, locations
end

---@param t testing.T
function test.cpu_only_atlas_and_plain_locations(t)
	local source = imageData(4, 5)
	local atlases, locations = pack(ImageAtlasPacker(), {a = source})
	t:eq(#atlases, 1)
	t:tdeq({atlases[1]:getDimensions()}, {6, 7})
	t:tdeq(locations, {a = {layer = 1, x = 1, y = 1, width = 4, height = 5}})
	t:eq(getmetatable(locations.a), nil)
	t:tdeq(atlases[1].pastes[1], {source, 1, 1, 0, 0, 4, 5})
	t:eq(#atlases[1].pastes, 9)
end

---@param t testing.T
function test.empty_input(t)
	local atlases, locations = pack(ImageAtlasPacker(), {})
	t:tdeq(atlases, {})
	t:tdeq(locations, {})
end

---@param t testing.T
function test.deterministic_rows_and_layers(t)
	local packer = ImageAtlasPacker()
	packer.max_atlas_width = 12
	packer.max_atlas_height = 12
	local sources = {
		d = imageData(4, 4), c = imageData(4, 4),
		b = imageData(4, 4), a = imageData(4, 4), e = imageData(4, 4),
	}
	local atlases, locations = pack(packer, sources)
	t:eq(#atlases, 2)
	t:tdeq({atlases[1]:getDimensions()}, {12, 12})
	t:tdeq({atlases[2]:getDimensions()}, {6, 6})
	t:tdeq(locations, {
		a = {layer = 1, x = 1, y = 1, width = 4, height = 4},
		b = {layer = 1, x = 7, y = 1, width = 4, height = 4},
		c = {layer = 1, x = 1, y = 7, width = 4, height = 4},
		d = {layer = 1, x = 7, y = 7, width = 4, height = 4},
		e = {layer = 2, x = 1, y = 1, width = 4, height = 4},
	})
	local _, again = pack(packer, sources)
	t:tdeq(again, locations)
end

---@param t testing.T
function test.sorts_by_height_then_width_then_name(t)
	local packer = ImageAtlasPacker()
	packer.border = 0
	local _, locations = pack(packer, {
		small = imageData(2, 2), tall = imageData(1, 4),
		b = imageData(3, 2), a = imageData(3, 2),
	})
	t:eq(locations.tall.x, 0)
	t:eq(locations.a.x, 1)
	t:eq(locations.b.x, 4)
	t:eq(locations.small.x, 7)
end

---@param t testing.T
function test.zero_border(t)
	local packer = ImageAtlasPacker()
	packer.border = 0
	packer.max_atlas_width = 4
	packer.max_atlas_height = 5
	local atlases, locations = pack(packer, {a = imageData(4, 5)})
	t:tdeq({atlases[1]:getDimensions()}, {4, 5})
	t:tdeq(locations.a, {layer = 1, x = 0, y = 0, width = 4, height = 5})
	t:eq(#atlases[1].pastes, 1)
end

---@param t testing.T
function test.oversized_image_fails(t)
	local packer = ImageAtlasPacker()
	packer.max_atlas_width = 16
	packer.max_atlas_height = 16
	for _, dimensions in ipairs({{15, 2}, {2, 15}}) do
		local err = t:has_error(function()
			pack(packer, {large = imageData(unpack(dimensions))})
		end)
		t:eq(err, "image `large` does not fit in an atlas")
	end
end

---@param t testing.T
function test.invalid_settings(t)
	for _, value in ipairs({-1, 0.5}) do
		local packer = ImageAtlasPacker()
		packer.border = value
		t:eq(t:has_error(function() pack(packer, {}) end), "border must be a non-negative integer")
	end
	---@type ("max_atlas_width"|"max_atlas_height")[]
	local fields = {"max_atlas_width", "max_atlas_height"}
	for _, field in ipairs(fields) do
		for _, value in ipairs({0, -1, 1.5}) do
			local packer = ImageAtlasPacker()
			---@cast packer table<string, number>
			packer[field] = value
			t:eq(t:has_error(function() pack(packer, {}) end), field .. " must be a positive integer")
		end
	end
end

---@param t testing.T
function test.large_image(t)
	local atlases, locations = pack(ImageAtlasPacker(), {large = imageData(1537, 2)})
	t:eq(#atlases, 1)
	t:tdeq({atlases[1]:getDimensions()}, {1539, 4})
	t:eq(locations.large.width, 1537)
end

-- Real pixel tests run with ./test-love.
---@param t testing.T
function test.pixels_and_extruded_border(t)
	if not love.image then return end
	local source = love.image.newImageData(2, 2)
	source:setPixel(0, 0, 1, 0, 0, 1)
	source:setPixel(1, 0, 0, 1, 0, 0.5)
	source:setPixel(0, 1, 0, 0, 1, 1)
	source:setPixel(1, 1, 1, 1, 1, 0)
	local packer = ImageAtlasPacker()
	packer.border = 3
	local atlases, locations = packer:pack({a = source})
	local atlas = atlases[1]
	t:assert(atlas:typeOf("ImageData"))
	t:tdeq({atlas:getDimensions()}, {8, 8})
	t:tdeq(locations.a, {layer = 1, x = 3, y = 3, width = 2, height = 2})
	for y = 0, 7 do
		for x = 0, 7 do
			local sx = math.min(math.max(x - 3, 0), 1)
			local sy = math.min(math.max(y - 3, 0), 1)
			t:tdeq({atlas:getPixel(x, y)}, {source:getPixel(sx, sy)})
		end
	end
	atlas:release()
	source:release()
end

---@param t testing.T
function test.border_wider_than_source(t)
	if not love.image then return end
	local source = love.image.newImageData(1, 1)
	source:setPixel(0, 0, 1, 0, 1, 1)
	local packer = ImageAtlasPacker()
	packer.border = 2
	local atlases = packer:pack({a = source})
	for y = 0, 4 do
		for x = 0, 4 do
			t:tdeq({atlases[1]:getPixel(x, y)}, {1, 0, 1, 1})
		end
	end
	atlases[1]:release()
	source:release()
end

return test
