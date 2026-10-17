local class = require("class")
local Video = require("Video")

---@class rizu.sprite.VideoEngine
---@operator call: rizu.sprite.VideoEngine
local VideoEngine = class()

function VideoEngine:new()
	---@type {[string]: video.Video}
	self.videos = {}
end

---@param video_names string[]
---@param resources {[string]: string}
function VideoEngine:load(video_names, resources)
	self:unload()
	for _, name in ipairs(video_names) do
		local content = resources[name]
		if content then
			local fileData = love.filesystem.newFileData(content, tostring(name))
			local ok, video = pcall(Video, fileData)
			if ok and video then
				self.videos[name] = video
			end
		end
	end
end

function VideoEngine:unload()
	for _, video in pairs(self.videos) do
		video:release()
	end
	self.videos = {}
end

function VideoEngine:rewind()
	for _, video in pairs(self.videos) do
		video:rewind()
	end
end

---@param name string
---@param time number
function VideoEngine:seek(name, time)
	local video = self.videos[name]
	if video then
		video:seek(time)
	end
end

---@param name string|integer
---@return video.Video?
function VideoEngine:get(name)
	return self.videos[name]
end

return VideoEngine
