local class = require("class")
local AtlasImage = require("gui.AtlasImage")
local ImageSprite = require("gui.ImageSprite")

---@class gui.packer.ImageAtlasPacker
---@operator call: gui.packer.ImageAtlasPacker
---@field max_atlas_width integer
---@field max_atlas_height integer
---@field image_size_constraint integer
---@field border integer
local ImageAtlasPacker = class()

ImageAtlasPacker.max_atlas_width = 4096
ImageAtlasPacker.max_atlas_height = 4096
ImageAtlasPacker.image_size_constraint = 1536
ImageAtlasPacker.border = 1

---@class gui.packer.ImageAtlasPacker.Entry
---@field name string
---@field image_data love.ImageData
---@field width integer
---@field height integer
---@field x integer
---@field y integer
---@field layer integer

---@param image_datas {[string]: love.ImageData}
---@return gui.packer.ImageAtlasPacker.Entry[] packed
---@return gui.packer.ImageAtlasPacker.Entry[] standalone
function ImageAtlasPacker:buildEntries(image_datas)
	---@type gui.packer.ImageAtlasPacker.Entry[]
	local packed = {}
	---@type gui.packer.ImageAtlasPacker.Entry[]
	local standalone = {}

	for name, image_data in pairs(image_datas) do
		local width, height = image_data:getDimensions()
		local entry = {
			name = name,
			image_data = image_data,
			width = width,
			height = height,
			x = 0,
			y = 0,
			layer = 0,
		}
		if width > self.image_size_constraint or height > self.image_size_constraint then
			standalone[#standalone + 1] = entry
		else
			packed[#packed + 1] = entry
		end
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
	table.sort(packed, sort_entries)
	table.sort(standalone, sort_entries)
	return packed, standalone
end

---@param entries gui.packer.ImageAtlasPacker.Entry[]
---@return integer layer_count
function ImageAtlasPacker:placeEntries(entries)
	local border = self.border
	local x, y, row_height = border, border, 0
	local layer = 1

	for _, entry in ipairs(entries) do
		local packed_width = entry.width + border * 2
		local packed_height = entry.height + border * 2
		assert(packed_width <= self.max_atlas_width and packed_height <= self.max_atlas_height,
			("sprite `%s` does not fit in an atlas"):format(entry.name))

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
---@param entry gui.packer.ImageAtlasPacker.Entry
function ImageAtlasPacker:pasteEntry(atlas, entry)
	local border = self.border
	local x, y = entry.x, entry.y
	local width, height = entry.width, entry.height
	atlas:paste(entry.image_data, x, y, 0, 0, width, height)
	if border == 0 then
		return
	end

	atlas:paste(entry.image_data, x - border, y, 0, 0, border, height)
	atlas:paste(entry.image_data, x + width, y, width - border, 0, border, height)
	atlas:paste(entry.image_data, x, y - border, 0, 0, width, border)
	atlas:paste(entry.image_data, x, y + height, 0, height - border, width, border)
	atlas:paste(entry.image_data, x - border, y - border, 0, 0, border, border)
	atlas:paste(entry.image_data, x + width, y - border, width - border, 0, border, border)
	atlas:paste(entry.image_data, x - border, y + height, 0, height - border, border, border)
	atlas:paste(entry.image_data, x + width, y + height, width - border, height - border, border, border)
end

---@param image_datas {[string]: love.ImageData}
---@return love.Image[] atlases
---@return {[string]: gui.Sprite} sprites
function ImageAtlasPacker:pack(image_datas)
	local entries, standalone = self:buildEntries(image_datas)
	local layer_count = self:placeEntries(entries)
	---@type integer[]
	local layer_widths = {}
	---@type integer[]
	local layer_heights = {}
	for layer = 1, layer_count do
		layer_widths[layer] = 0
		layer_heights[layer] = 0
	end
	for _, entry in ipairs(entries) do
		local layer = entry.layer
		layer_widths[layer] = math.max(layer_widths[layer], entry.x + entry.width + self.border)
		layer_heights[layer] = math.max(layer_heights[layer], entry.y + entry.height + self.border)
	end

	---@type love.ImageData[]
	local layers = {}
	for layer = 1, layer_count do
		layers[layer] = love.image.newImageData(layer_widths[layer], layer_heights[layer])
	end
	for _, entry in ipairs(entries) do
		self:pasteEntry(layers[entry.layer], entry)
	end

	---@type love.Image[]
	local atlases = {}
	---@type {[string]: gui.Sprite}
	local sprites = {}
	for layer, image_data in ipairs(layers) do
		local atlas = love.graphics.newImage(image_data)
		atlas:setWrap("clamp", "clamp")
		atlases[layer] = atlas
	end
	for _, entry in ipairs(entries) do
		local layer = entry.layer
		local quad = love.graphics.newQuad(entry.x, entry.y, entry.width, entry.height,
			layer_widths[layer], layer_heights[layer])
		sprites[entry.name] = AtlasImage(atlases[layer], quad)
	end

	for _, entry in ipairs(standalone) do
		local image = love.graphics.newImage(entry.image_data)
		image:setWrap("clamp", "clamp")
		sprites[entry.name] = ImageSprite(image)
	end

	return atlases, sprites
end

return ImageAtlasPacker
