local class = require("class")
local ImageDataDecoder = require("ImageDataDecoder")

---@class rizu.sprite.SpriteEngine
---@operator call: rizu.sprite.SpriteEngine
local SpriteEngine = class()

function SpriteEngine:new()
	---@type {[string]: love.Image}
	self.images = {}
end

---@param image_names string[]
---@param resources {[string]: string}
function SpriteEngine:load(image_names, resources)
	self:unload()
	for _, name in ipairs(image_names) do
		local content = resources[name]
		if content then
			local fileData = love.filesystem.newFileData(content, tostring(name))
			local imageData = ImageDataDecoder.decodeFileData(fileData, tostring(name))
			if imageData then
				self.images[name] = love.graphics.newImage(imageData)
			end
		end
	end
end

function SpriteEngine:unload()
	for _, image in pairs(self.images) do
		image:release()
	end
	self.images = {}
end

---@param name string
---@return love.Image?
function SpriteEngine:get(name)
	return self.images[name]
end

return SpriteEngine
