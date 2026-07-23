local class = require("class")

---@class gui.packer.ImageAtlasPacker
---@operator call: gui.packer.ImageAtlasPacker
local ImageAtlasPacker = class()

ImageAtlasPacker.gap = 0
ImageAtlasPacker.border = 1

---@class gui.packer.ImageAtlasPacker.Entry
---@field name string
---@field image_data love.ImageData
---@field width integer
---@field height integer
---@field packed_width integer
---@field packed_height integer
---@field x integer
---@field y integer

---@private
---@param sprites {[string]: love.ImageData}
---@return gui.packer.ImageAtlasPacker.Entry[]
---@return string?
function ImageAtlasPacker:buildEntries(sprites)
	---@type gui.packer.ImageAtlasPacker.Entry[]
	local entries = {}
	local atlas_format = nil ---@type string

	for name, image_data in pairs(sprites) do
		local width, height = image_data:getDimensions()
		local format = image_data.getFormat and image_data:getFormat() or nil

		if atlas_format and format and atlas_format ~= format then
			error(("all sprites must share the same ImageData format: `%s` ~= `%s`"):format(atlas_format, format))
		end

		atlas_format = atlas_format or format

		entries[#entries + 1] = {
			name = name,
			image_data = image_data,
			width = width,
			height = height,
			packed_width = width + self.border * 2,
			packed_height = height + self.border * 2,
			x = 0,
			y = 0,
		}
	end

	table.sort(entries, function(a, b)
		if a.height ~= b.height then
			return a.height > b.height
		end
		if a.width ~= b.width then
			return a.width > b.width
		end
		return a.name < b.name
	end)

	return entries, atlas_format
end

---@private
---@param entries gui.packer.ImageAtlasPacker.Entry[]
---@param atlas_width integer
---@return {width: integer, height: integer, area: integer}
function ImageAtlasPacker:packShelves(entries, atlas_width)
	local x = 0
	local y = 0
	local row_height = 0
	local used_width = 0

	for _, entry in ipairs(entries) do
		if x > 0 and x + entry.packed_width > atlas_width then
			x = 0
			y = y + row_height + self.gap
			row_height = 0
		end

		entry.x = x
		entry.y = y

		x = x + entry.packed_width + self.gap
		row_height = math.max(row_height, entry.packed_height)
		used_width = math.max(used_width, x - self.gap) ---@type number
	end

	local atlas_height = y + row_height

	return {
		width = math.max(used_width, 1),
		height = math.max(atlas_height, 1),
		area = math.max(used_width, 1) * math.max(atlas_height, 1),
	}
end

---@private
---@param entries gui.packer.ImageAtlasPacker.Entry[]
---@return {width: integer, height: integer}
function ImageAtlasPacker:selectLayout(entries)
	local max_width = 1
	local total_width = 0
	local total_area = 0

	for _, entry in ipairs(entries) do
		max_width = math.max(max_width, entry.packed_width)
		total_width = total_width + entry.packed_width + self.gap
		total_area = total_area + (entry.packed_width + self.gap) * (entry.packed_height + self.gap)
	end

	total_width = math.max(total_width - self.gap, max_width)

	local target_width = math.max(max_width, math.ceil(math.sqrt(total_area)))
	local candidate_widths = {[max_width] = true, [target_width] = true, [total_width] = true}

	local width = max_width
	while width < total_width do
		candidate_widths[width] = true
		width = width * 2
	end

	---@type integer[]
	local candidates = {}
	for candidate_width in pairs(candidate_widths) do
		candidates[#candidates + 1] = candidate_width
	end
	table.sort(candidates)

	local best_layout = nil
	local best_score = nil
	local best_aspect_delta = nil

	for _, candidate_width in ipairs(candidates) do
		local layout = self:packShelves(entries, candidate_width)
		local aspect_delta = math.abs(layout.width - layout.height)

		if not best_layout
			or layout.area < best_score
			or (layout.area == best_score and aspect_delta < best_aspect_delta)
			or (layout.area == best_score and aspect_delta == best_aspect_delta and layout.width < best_layout.width)
		then
			best_layout = {
				width = layout.width,
				height = layout.height,
			}
			best_score = layout.area
			best_aspect_delta = aspect_delta
		end
	end

	assert(best_layout)
	self:packShelves(entries, best_layout.width)

	return best_layout
end

---@private
---@param atlas love.ImageData
---@param entry gui.packer.ImageAtlasPacker.Entry
function ImageAtlasPacker:pasteEntry(atlas, entry)
	local border = self.border
	local inner_x = entry.x + border
	local inner_y = entry.y + border
	local width = entry.width
	local height = entry.height

	atlas:paste(entry.image_data, inner_x, inner_y, 0, 0, width, height)

	if border == 0 then
		return
	end

	local right_x = inner_x + width
	local bottom_y = inner_y + height

	atlas:paste(entry.image_data, inner_x - border, inner_y, 0, 0, border, height)
	atlas:paste(entry.image_data, right_x, inner_y, width - border, 0, border, height)
	atlas:paste(entry.image_data, inner_x, inner_y - border, 0, 0, width, border)
	atlas:paste(entry.image_data, inner_x, bottom_y, 0, height - border, width, border)

	atlas:paste(entry.image_data, inner_x - border, inner_y - border, 0, 0, border, border)
	atlas:paste(entry.image_data, right_x, inner_y - border, width - border, 0, border, border)
	atlas:paste(entry.image_data, inner_x - border, bottom_y, 0, height - border, border, border)
	atlas:paste(entry.image_data, right_x, bottom_y, width - border, height - border, border, border)
end

---@param sprites {[string]: love.ImageData}
---@return love.ImageData
---@return {[string]: love.Quad}
function ImageAtlasPacker:pack(sprites)
	local entries, atlas_format = self:buildEntries(sprites)

	if #entries == 0 then
		return love.image.newImageData(1, 1), {}
	end

	local layout = self:selectLayout(entries)

	local atlas ---@type love.ImageData
	if atlas_format then
		atlas = love.image.newImageData(layout.width, layout.height, atlas_format)
	else
		atlas = love.image.newImageData(layout.width, layout.height)
	end

	---@type {[string]: love.Quad}
	local quads = {}

	for _, entry in ipairs(entries) do
		self:pasteEntry(atlas, entry)
		quads[entry.name] = love.graphics.newQuad(
			entry.x + self.border,
			entry.y + self.border,
			entry.width,
			entry.height,
			layout.width,
			layout.height
		)
	end

	return atlas, quads
end

return ImageAtlasPacker
