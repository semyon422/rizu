local class = require("class")
local thread = require("thread")
local ImageDataDecoder = require("ImageDataDecoder")

---@class rizu.online.AvatarCache.Entry
---@field state "pending"|"ready"|"failed"
---@field image love.Image?

---@class rizu.online.AvatarCache
---@operator call: rizu.online.AvatarCache
---@field network rizu.NetworkService
---@field entries {[string]: rizu.online.AvatarCache.Entry}
local AvatarCache = class()

---@param network rizu.NetworkService
function AvatarCache:new(network)
	self.network = assert(network, "network is required")
	self.entries = {}
end

---@param url string
---@return love.Image?
function AvatarCache:download(url)
	local res, err = self.network:download(url)
	if not res then
		print("AvatarCache: download failed for " .. url .. ": " .. tostring(err))
		return
	end
	if res.status < 200 or res.status >= 300 then
		print("AvatarCache: download failed for " .. url .. ": HTTP " .. res.status)
		return
	end

	local file_data = love.filesystem.newFileData(res.body, url)
	local image_data = ImageDataDecoder.decodeFileData(file_data, url)
	if image_data then
		local image = love.graphics.newImage(image_data, {mipmaps = true})
		image:setFilter("linear", "linear", 1)
		return image
	end
end

---@param url string?
---@return love.Image?
function AvatarCache:get(url)
	if type(url) ~= "string" or url == "" then return end
	local entry = self.entries[url]
	if entry then return entry.image end

	entry = {state = "pending"}
	self.entries[url] = entry
	thread.coro(function()
		local image = self:download(url)
		if self.entries[url] ~= entry then
			if image then image:release() end
			return
		end
		-- A failed url stays failed until clear(), so it is not downloaded again every frame.
		entry.state = image and "ready" or "failed"
		entry.image = image
	end)()
end

function AvatarCache:clear()
	for _, entry in pairs(self.entries) do
		if entry.image then entry.image:release() end
	end
	self.entries = {}
end

return AvatarCache
