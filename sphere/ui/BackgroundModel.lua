local class = require("class")
local thread = require("thread")
local gfx_util = require("gfx_util")
local flux = require("flux")
local delay = require("delay")

local loadHttpImage

---@class sphere.BackgroundModel
---@operator call: sphere.BackgroundModel
---@field network rizu.NetworkService
---@field http_image_loader fun(body: string, url: string): love.ImageData?
local BackgroundModel = class()

BackgroundModel.alpha = 0

local loadDefaults = thread.async(function()
	require("love.filesystem")
	require("love.image")
	local ImageDataDecoder = require("ImageDataDecoder")
	local images = {}
	for _, name in ipairs(love.filesystem.getDirectoryItems("userdata/backgrounds")) do
		local data = ImageDataDecoder.decodePath("userdata/backgrounds/" .. name)
		if data then images[#images + 1] = data end
	end
	return images
end)

local findBackground = thread.async(function(path)
	require("love.filesystem")
	local BackgroundFinder = require("rizu.preview.BackgroundFinder")
	local LoveFilesystem = require("fs.LoveFilesystem")
	return BackgroundFinder(LoveFilesystem()):find(path)
end)

---@param network rizu.NetworkService
---@param http_image_loader fun(body: string, url: string): love.ImageData?
function BackgroundModel:new(network, http_image_loader)
	self.network = assert(network, "network is required")
	self.http_image_loader = http_image_loader or loadHttpImage
	self.background_finder = findBackground
	self.generation = 0
end

function BackgroundModel:load()
	self.path = ""

	self.emptyImage = gfx_util.newPixel(0.25, 0.25, 0.25, 1)
	self.images = {self.emptyImage}

	self.defaults_pending = true
end

function BackgroundModel:loadDefaults()
	self.defaults_pending = false
	thread.coro(function()
		local data = loadDefaults()
		local images = {}
		for _, image_data in ipairs(data) do
			images[#images + 1] = love.graphics.newImage(image_data)
			image_data:release()
		end
		self.defaultImages = images
	end)()
end

function BackgroundModel:getDefaultImage()
	if not self.defaultImages or #self.defaultImages == 0 then
		return self.emptyImage
	end

	local randomIndex = love.math.random(#self.defaultImages)
	return self.defaultImages[randomIndex]
end

---@param path string?
function BackgroundModel:setBackgroundPath(path)
	if self.path ~= path then
		self.path = path
		self:loadBackgroundDebounce()
	end
end

function BackgroundModel:update()
	if self.defaults_pending then self:loadDefaults() end
	if #self.images > 1 then
		if self.alpha == 1 then
			table.remove(self.images, 1)
			self.alpha = 0
		elseif self.alpha == 0 then
			flux.to(self, 0.25, {alpha = 1}):ease("quadinout")
		end
	end
end

---@param image love.Image
function BackgroundModel:setBackground(image)
	local layer = math.min(#self.images + 1, 3)
	self.images[layer] = image
	if layer == 2 then
		self.alpha = 0
	end
end

---@param path string?
function BackgroundModel:loadBackgroundDebounce(path)
	self.path = path or self.path
	self.generation = self.generation + 1
	delay.debounce(self, "loadDebounce", 0.1, self.loadBackground, self)
end

function BackgroundModel:loadBackground()
	local path = self.path
	local generation = self.generation
	if not path then
		self:setBackground(self:getDefaultImage())
		return
	end

	if not path:find("^http") and not path:find("%.ojn$") and not path:find("%.mid$") then
		path = self.background_finder(path)
		if generation ~= self.generation then return end
		if not path then
			self:setBackground(self:getDefaultImage())
			return
		end
	end

	local image
	if path:find("%.ojn$") then
		image = self:loadImage(path, "ojn")
	elseif path:find("^http") then
		image = self:loadImage(path, "http")
	elseif path:find("%.mid$") then
		image = self:loadImage("resources/midi/background.jpg")
	else
		image = self:loadImage(path)
	end

	if generation ~= self.generation then
		if image then image:release() end
		return
	end

	if image then
		self:setBackground(image)
		return
	end

	self:setBackground(self.emptyImage)
end

local loadImage = thread.async(function(path)
	require("love.filesystem")
	require("love.image")
	local ImageDataDecoder = require("ImageDataDecoder")

	local info = love.filesystem.getInfo(path)
	if not info then
		return
	end

	return ImageDataDecoder.decodePath(path)
end)

local loadOJN = thread.async(function(path)
	require("love.filesystem")
	require("love.image")
	local OJN = require("chart.format.o2jam.OJN")
	local ImageDataDecoder = require("ImageDataDecoder")

	local content = love.filesystem.read(path)
	if not content then
		return
	end

	local ojn = OJN(content)
	if ojn.cover == "" then
		return
	end

	local fileData = love.filesystem.newFileData(ojn.cover, "cover")
	return ImageDataDecoder.decodeFileData(fileData, path .. ":cover")
end)

loadHttpImage = thread.async(function(body, url)
	require("love.filesystem")
	require("love.image")
	local ImageDataDecoder = require("ImageDataDecoder")
	local fileData = love.filesystem.newFileData(body, "cover")
	return ImageDataDecoder.decodeFileData(fileData, url)
end)

---@param path string
---@param type string?
---@return love.Image?
function BackgroundModel:loadImage(path, type)
	local imageData
	if type == "ojn" then
		imageData = loadOJN(path)
	elseif type == "http" then
		local res = self.network:request(path)
		if not res or res.status >= 400 then
			return
		end
		imageData = self.http_image_loader(res.body, path)
	else
		imageData = loadImage(path)
	end
	if not imageData then
		return
	end
	return love.graphics.newImage(imageData)
end

return BackgroundModel
