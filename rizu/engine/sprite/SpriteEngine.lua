local class = require("class")
local ImageDataDecoder = require("ImageDataDecoder")

---@class rizu.sprite.SpriteEngine
---@operator call: rizu.sprite.SpriteEngine
local SpriteEngine = class()

function SpriteEngine:new()
	---@type {[string]: love.Image}
	self.images = {}
	---@type {[string]: string}
	self.resources = {}
	---@type {[string]: true}
	self.image_names = {}
end

---@param image_names string[]
---@param resources {[string]: string}
function SpriteEngine:load(image_names, resources)
	self:unload()
	for _, name in ipairs(image_names) do
		if resources[name] then
			self.image_names[name] = true
		end
	end
	self.resources = resources
end

function SpriteEngine:unload()
	for _, image in pairs(self.images) do
		image:release()
	end
	self.images = {}
	self.resources = {}
	self.image_names = {}
end

---@param name string
---@return love.Image?
function SpriteEngine:get(name)
	local image = self.images[name]
	if image then
		return image
	end
	if not self.image_names[name] then
		return
	end

	local content = self.resources[name]
	if not content then
		return
	end

	local fileData = love.filesystem.newFileData(content, tostring(name))
	local imageData = ImageDataDecoder.decodeFileData(fileData, tostring(name))
	if not imageData then
		self.image_names[name] = nil
		self.resources[name] = nil
		return
	end

	image = love.graphics.newImage(imageData)
	self.images[name] = image
	self.resources[name] = nil
	return image
end

return SpriteEngine
