local class = require("class")
local thread = require("thread")

---@class ui.screens.dlc.ThumbnailCache.Entry
---@field state "pending"|"ready"
---@field image love.Image?
---@field downloaded_at number?
---@field last_used integer

---Session-only, cache-owned thumbnail storage with request de-duplication and LRU eviction.
---@class ui.screens.dlc.ThumbnailCache
---@operator call: ui.screens.dlc.ThumbnailCache
---@field private entries {[string]: ui.screens.dlc.ThumbnailCache.Entry}
---@field private load_image fun(url: string): love.Image?, string?
---@field private start fun(task: fun())
---@field private now fun(): number
---@field private capacity integer
---@field private access_counter integer
---@field private generation integer
local ThumbnailCache = class()

---@param load_image fun(url: string): love.Image?, string?
---@param capacity integer?
---@param config {start: fun(task: fun())?, now: fun(): number?}?
function ThumbnailCache:new(load_image, capacity, config)
	config = config or {}
	self.load_image = assert(load_image, "thumbnail loader is required")
	self.capacity = capacity or 100
	assert(self.capacity >= 1, "thumbnail cache capacity must be positive")
	self.start = config.start or function(task)
		thread.coro(task)()
	end
	self.now = config.now or function()
		return love.timer.getTime()
	end
	self.entries = {}
	self.access_counter = 0
	self.generation = 0
end

---@private
---@return integer
function ThumbnailCache:nextAccess()
	self.access_counter = self.access_counter + 1
	return self.access_counter
end

---@param url string
---@param request boolean? Start a missing request. Defaults to true.
---@return love.Image? image
---@return number? downloaded_at
---@return "missing"|"pending"|"ready" state
function ThumbnailCache:get(url, request)
	local entry = self.entries[url]
	if entry then
		entry.last_used = self:nextAccess()
		return entry.image, entry.downloaded_at, entry.state
	end
	if request == false then
		return nil, nil, "missing"
	end

	entry = {state = "pending", last_used = self:nextAccess()}
	self.entries[url] = entry
	local generation = self.generation
	self.start(function()
		local image = self.load_image(url)
		if generation ~= self.generation or self.entries[url] ~= entry then
			if image and image.release then image:release() end
			return
		end
		if not image then
			self.entries[url] = nil
			return
		end
		entry.state = "ready"
		entry.image = image
		entry.downloaded_at = self.now()
		entry.last_used = self:nextAccess()
		self:evict()
	end)
	return nil, nil, "missing"
end

---@private
function ThumbnailCache:evict()
	local ready_count = 0
	for _, entry in pairs(self.entries) do
		if entry.state == "ready" then ready_count = ready_count + 1 end
	end
	while ready_count > self.capacity do
		local oldest_url ---@type string?
		local oldest_access = math.huge
		for url, entry in pairs(self.entries) do
			if entry.state == "ready" and entry.last_used < oldest_access then
				oldest_url = url
				oldest_access = entry.last_used
			end
		end
		if not oldest_url then break end
		local entry = self.entries[oldest_url]
		self.entries[oldest_url] = nil
		if entry.image and entry.image.release then entry.image:release() end
		ready_count = ready_count - 1
	end
end

function ThumbnailCache:clear()
	self.generation = self.generation + 1
	for _, entry in pairs(self.entries) do
		if entry.image and entry.image.release then entry.image:release() end
	end
	self.entries = {}
end

---@return integer count
function ThumbnailCache:getReadyCount()
	local count = 0
	for _, entry in pairs(self.entries) do
		if entry.state == "ready" then count = count + 1 end
	end
	return count
end

return ThumbnailCache
