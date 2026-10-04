local class = require("class")

---@class rizu.skin.ImageAtlasPacker
---@operator call: rizu.skin.ImageAtlasPacker
---@field max_atlas_width integer
---@field max_atlas_height integer
---@field border integer Extruded edge pixels around each image
local ImageAtlasPacker = class()

ImageAtlasPacker.max_atlas_width = 4096
ImageAtlasPacker.max_atlas_height = 4096
ImageAtlasPacker.border = 1

---@class rizu.skin.ImageAtlasPacker.Location
---@field layer integer One-based atlas index
---@field x integer Pixel coordinates, excluding the border
---@field y integer
---@field width integer
---@field height integer

---@class rizu.skin.ImageAtlasPacker.Entry : rizu.skin.ImageAtlasPacker.Location
---@field name string
---@field image_data love.ImageData

---@param image_datas {[string]: love.ImageData}
---@return rizu.skin.ImageAtlasPacker.Entry[]
function ImageAtlasPacker:buildEntries(image_datas)
	local entries = {} ---@type rizu.skin.ImageAtlasPacker.Entry[]
	for name, image_data in pairs(image_datas) do
		local width, height = image_data:getDimensions()
		entries[#entries + 1] = {
			name = name,
			image_data = image_data,
			width = width,
			height = height,
			x = 0,
			y = 0,
			layer = 0,
		}
	end

	local function sort_entries(a, b)
		if a.height ~= b.height then
			return a.height > b.height
		end
		if a.width ~= b.width then
			return a.width > b.width
		end
		return a.name < b.name
	end
	table.sort(entries, sort_entries)
	return entries
end

---@param entries rizu.skin.ImageAtlasPacker.Entry[]
---@return integer layer_count
function ImageAtlasPacker:placeEntries(entries)
	local border = self.border
	local x, y, row_height = border, border, 0
	local layer = 1

	for _, entry in ipairs(entries) do
		local packed_width = entry.width + border * 2
		local packed_height = entry.height + border * 2
		assert(packed_width <= self.max_atlas_width and packed_height <= self.max_atlas_height,
			("image `%s` does not fit in an atlas"):format(entry.name))

		if x + packed_width - border > self.max_atlas_width then
			x = border
			y = y + row_height
			row_height = 0
		end
		if y + packed_height - border > self.max_atlas_height then
			layer = layer + 1
			x, y, row_height = border, border, 0
		end

		entry.x = x
		entry.y = y
		entry.layer = layer
		x = x + packed_width
		row_height = math.max(row_height, packed_height)
	end

	return #entries == 0 and 0 or layer
end

---@param atlas love.ImageData
---@param entry rizu.skin.ImageAtlasPacker.Entry
function ImageAtlasPacker:pasteEntry(atlas, entry)
	local source = entry.image_data
	local x, y = entry.x, entry.y
	local width, height = entry.width, entry.height
	atlas:paste(source, x, y, 0, 0, width, height)

	-- Repeat the outermost pixels, including for borders wider than the source.
	for i = 1, self.border do
		atlas:paste(source, x - i, y, 0, 0, 1, height)
		atlas:paste(source, x + width + i - 1, y, width - 1, 0, 1, height)
		atlas:paste(source, x, y - i, 0, 0, width, 1)
		atlas:paste(source, x, y + height + i - 1, 0, height - 1, width, 1)
		for j = 1, self.border do
			atlas:paste(source, x - i, y - j, 0, 0, 1, 1)
			atlas:paste(source, x + width + i - 1, y - j, width - 1, 0, 1, 1)
			atlas:paste(source, x - i, y + height + j - 1, 0, height - 1, 1, 1)
			atlas:paste(source, x + width + i - 1, y + height + j - 1, width - 1, height - 1, 1, 1)
		end
	end
end

---CPU-only packing. Returned atlases are ImageData, not GPU Images or Canvases.
---Locations contain raw pixel rectangles; Image and Quad creation belongs to the caller.
---@param image_datas {[string]: love.ImageData}
---@return love.ImageData[] atlases
---@return {[string]: rizu.skin.ImageAtlasPacker.Location} locations
function ImageAtlasPacker:pack(image_datas)
	assert(self.max_atlas_width > 0 and self.max_atlas_width % 1 == 0,
		"max_atlas_width must be a positive integer")
	assert(self.max_atlas_height > 0 and self.max_atlas_height % 1 == 0,
		"max_atlas_height must be a positive integer")
	assert(self.border >= 0 and self.border % 1 == 0, "border must be a non-negative integer")

	local entries = self:buildEntries(image_datas)
	local layer_count = self:placeEntries(entries)
	local widths, heights = {}, {} ---@type integer[], integer[]
	for layer = 1, layer_count do
		widths[layer], heights[layer] = 0, 0
	end
	for _, entry in ipairs(entries) do
		local layer = entry.layer
		widths[layer] = math.max(widths[layer], entry.x + entry.width + self.border)
		heights[layer] = math.max(heights[layer], entry.y + entry.height + self.border)
	end

	local atlases = {} ---@type love.ImageData[]
	for layer = 1, layer_count do
		atlases[layer] = love.image.newImageData(widths[layer], heights[layer])
	end
	local locations = {} ---@type {[string]: rizu.skin.ImageAtlasPacker.Location}
	for _, entry in ipairs(entries) do
		self:pasteEntry(atlases[entry.layer], entry)
		locations[entry.name] = {
			layer = entry.layer,
			x = entry.x,
			y = entry.y,
			width = entry.width,
			height = entry.height,
		}
	end
	return atlases, locations
end

return ImageAtlasPacker
