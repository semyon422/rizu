local class = require("class")
local thread = require("thread")
local gfx_util = require("gfx_util")
local flux = require("flux")
local delay = require("delay")
local Path = require("Path")
local ImageDataDecoder = require("ImageDataDecoder")
local socket_url = require("socket.url")
local CosocketScheduler = require("web.luasocket.CosocketScheduler")
local http_util = require("web.http.util")

---@class sphere.BackgroundModel
---@operator call: sphere.BackgroundModel
---@field http_scheduler web.CosocketScheduler
---@field http_thread thread?
---@field http_url string?
local BackgroundModel = class()

BackgroundModel.alpha = 0

local defaultBackgroundsPath = "userdata/backgrounds"

function BackgroundModel:load()
	self.path = ""
	self.http_scheduler = CosocketScheduler()

	self.emptyImage = gfx_util.newPixel(0.25, 0.25, 0.25, 1)
	self.images = {self.emptyImage}

	local dir = love.filesystem.getDirectoryItems(defaultBackgroundsPath)

	if not dir or #dir == 0 then
		return
	end

	self.defaultImages = {}
	for _, item in ipairs(dir) do
		local path = defaultBackgroundsPath .. "/" .. item
		local imageData = ImageDataDecoder.decodePath(path)

		if imageData then
			local image = love.graphics.newImage(imageData)
			table.insert(self.defaultImages, image)
		end
	end
end

function BackgroundModel:getDefaultImage()
	if not self.defaultImages then
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
	if self.http_scheduler then
		local ok, err = self.http_scheduler:update(0)
		if not ok and err then
			print(("background http scheduler error: %s"):format(err))
		end
	end

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
	delay.debounce(self, "loadDebounce", 0.1, self.loadBackground, self)
end

local image_ext = {
	png = true,
	jpg = true,
	jpeg = true,
	tga = true,
	bmp = true,
}

---@param path string?
---@return boolean
function BackgroundModel:isValidImage(path)
	if not path then
		return false
	end
	local ext = Path(path):getExtension()
	ext = ext and ext:lower()
	if not ext or not image_ext[ext] then
		return false
	end
	local info = love.filesystem.getInfo(path)
	return info and info.type ~= "directory"
end

---@return string?
function BackgroundModel:findBackground()
	if not self.path then
		return
	end

	local path = Path(self.path):normalize()

	if self:isValidImage(tostring(path)) then
		return tostring(path)
	end


	local path_info = love.filesystem.getInfo(tostring(path))

	local search_directory ---@type aqua.Path
	if path_info and path_info.type == "directory" then
		path = path:toDirectory()
		search_directory = path
	else
		search_directory = path:trimLast()
	end

	local original_file_name = path:isFile() and path:getName(true)
	local files = love.filesystem.getDirectoryItems(tostring(search_directory))
	local found = nil ---@type string?
	local last_resort = nil ---@type string?

	for _, filepath_str in ipairs(files) do
		local filepath = Path(filepath_str)

		local ext = filepath:getExtension()
		if ext and image_ext[ext] then
			local c = filepath:getName(true):lower()

			if c:find("cdtitle") or c:find("banner") or c == "bn" then
				-- ignore
			elseif c:find("background") then
				found = filepath_str
				break
			elseif c:find("bg") then
				found = filepath_str
				break
			elseif original_file_name and c:find(original_file_name) then
				found = filepath_str
				break
			else
				last_resort = filepath_str
			end
		end
	end

	if not found and not last_resort then
		return
	end

	local result = tostring(search_directory .. Path(found or last_resort))

	if self:isValidImage(result) then
		return result
	end
end

function BackgroundModel:loadBackground()
	local path = self.path
	if not path then
		self.http_url = nil
		self:setBackground(self:getDefaultImage())
		return
	end

	if not path:find("^http") then
		if not self:isValidImage(path) then
			path = self:findBackground()
			if not path then
				self.http_url = nil
				self:setBackground(self:getDefaultImage())
				return
			end
		end
	end

	local image
	if path:find("%.ojn$") then
		self.http_url = nil
		image = self:loadImage(path, "ojn")
	elseif path:find("^http") then
		self:startHttpLoad(path)
		return
	elseif path:find("%.mid$") then
		self.http_url = nil
		image = self:loadImage("resources/midi/background.jpg")
	else
		self.http_url = nil
		image = self:loadImage(path)
	end

	self.path = path

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

local resolve_host_async = thread.async(function(host)
	local socket = require("socket")
	return socket.dns.toip(host)
end)

---@param url string
function BackgroundModel:startHttpLoad(url)
	self.http_url = url

	self.http_thread = coroutine.create(function()
		local parsed_url, parse_err = socket_url.parse(url)
		if not parsed_url or not parsed_url.host then
			self:finishHttpLoad(url, nil, parse_err or "invalid url")
			return
		end

		local connect_host, dns_err = resolve_host_async(parsed_url.host)
		if self.http_url ~= url then
			return
		end
		if not connect_host then
			self:finishHttpLoad(url, nil, dns_err)
			return
		end

		local ok, res = pcall(http_util.request, url, nil, {
			scheduler = self.http_scheduler,
			connect_host = connect_host,
			timeout = 10,
		})
		if self.http_url ~= url then
			return
		end
		if not ok then
			self:finishHttpLoad(url, nil, res)
			return
		end
		if not res then
			self:finishHttpLoad(url, nil, "request failed")
			return
		end
		if res.status >= 400 then
			self:finishHttpLoad(url, nil, "HTTP " .. res.status)
			return
		end

		local fileData = love.filesystem.newFileData(res.body, "cover")
		local imageData = ImageDataDecoder.decodeFileData(fileData, url)
		self:finishHttpLoad(url, imageData)
	end)

	local ok, err = coroutine.resume(self.http_thread)
	if not ok then
		self.http_thread = nil
		self:finishHttpLoad(url, nil, err)
	end
end

---@param url string
---@param imageData love.ImageData?
---@param err string?
function BackgroundModel:finishHttpLoad(url, imageData, err)
	if self.http_url ~= url then
		return
	end

	self.http_thread = nil
	if not imageData then
		if err then
			print(("background http load failed: %s"):format(err))
		end
		self:setBackground(self.emptyImage)
		return
	end

	self:setBackground(love.graphics.newImage(imageData))
end

---@param path string
---@param type string?
---@return love.Image?
function BackgroundModel:loadImage(path, type)
	local imageData
	if type == "ojn" then
		imageData = loadOJN(path)
	else
		imageData = loadImage(path)
	end
	if not imageData then
		return
	end
	return love.graphics.newImage(imageData)
end

return BackgroundModel
