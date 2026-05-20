local class = require("class")
local audio = require("audio")
local Video = require("Video")
local thread = require("thread")
local table_util = require("table_util")

local _newSoundDataAsync = thread.async(function(path, sample_gain)
	local fileData = love.filesystem.newFileData(path)
	if not fileData then
		return
	end
	local audio = require("audio")
	local soundData = audio.SoundData(fileData:getFFIPointer(), fileData:getSize())
	if soundData then
		soundData:amplify(sample_gain)
	end
	fileData:release()
	return soundData
end)

---@param path string
---@param sample_gain number
---@return audio.SoundData?
local function newSoundDataAsync(path, sample_gain)
	local soundData = _newSoundDataAsync(path, sample_gain)
	if not soundData then return end
	return setmetatable(soundData, audio.SoundData)
end

local newImageDataAsync = thread.async(function(s)
	require("love.image")
	local status, err = pcall(love.image.newImageData, s)
	if not status then return end
	return err
end)

---@param s string
---@return love.Image?
local function newImageAsync(s)
	local imageData = newImageDataAsync(s)
	if not imageData then return end
	return love.graphics.newImage(imageData)
end

local newFileDataAsync = thread.async(function(path)
	return love.filesystem.newFileData(path)
end)

---@param path string
---@return video.Video?
local function newVideoAsync(path)
	local fileData = newFileDataAsync(path)
	if not fileData then return end

	return Video(fileData)
end

local loadOjm = thread.async(function(path)
	local audio = require("audio")
	local OJM = require("chart.format.o2jam.OJM")

	local fileData, err = love.filesystem.newFileData(path)
	if not fileData then
		return false, err
	end

	local ojm = OJM(fileData:getFFIPointer(), fileData:getSize())
	local soundDatas = {}

	for sampleIndex, sampleData in pairs(ojm.samples) do
		local fd = love.filesystem.newFileData(sampleData, sampleIndex)
		soundDatas[sampleIndex] = audio.SoundData(fd:getFFIPointer(), fd:getSize())
	end

	return soundDatas
end)

---@param path string
---@return table?
local function loadOjmAsync(path)
	local soundDatas = loadOjm(path)
	if not soundDatas then
		return
	end
	for _, soundData in pairs(soundDatas) do
		setmetatable(soundData, audio.SoundData)
	end
	return soundDatas
end

---@class sphere.ResourceModel
---@operator call: sphere.ResourceModel
local ResourceModel = class()

---@param configModel sphere.ConfigModel
---@param fileFinder sphere.FileFinder
function ResourceModel:new(configModel, fileFinder)
	self.configModel = configModel
	self.fileFinder = fileFinder
	self.all_resources = {
		loaded = {},
		loading = {},
		not_loaded = {},
	}
	self.resources = self.all_resources.loaded
	self.sample_gain = 0
	self.aliases = {}
end

function ResourceModel:rewind()
	for _, resource in pairs(self.all_resources.loaded) do
		if resource.rewind then
			resource:rewind()
		end
	end
end

---@param chart ncdk2.Chart
---@param callback function
function ResourceModel:load(chart, callback)
	local fileFinder = self.fileFinder

	local settings = self.configModel.configs.settings
	local sample_gain = settings.audio.sampleGain
	local bga_image = settings.gameplay.bga.image
	local bga_video = settings.gameplay.bga.video
	if self.sample_gain ~= sample_gain then
		self:unloadAudio()
		self.sample_gain = sample_gain
	end

	self.callback = callback
	self.aliases = {}

	local loaded = {}
	for path, resource in pairs(self.all_resources.loaded) do
		table.insert(loaded, path)
	end
	self:rewind()

	local newResources = {}
	for _type, paths in chart.resources:iter() do
		local name = paths[1]
		for _, path in ipairs(paths) do
			local filePath
			if _type == "sound" then
				filePath = fileFinder:findFile(path, "audio")
			elseif _type == "image" then
				if bga_image then
					filePath = fileFinder:findFile(path, "image")
				end
				if bga_video and not filePath then
					filePath = fileFinder:findFile(path, "video")
				end
			elseif _type == "ojm" then
				filePath = fileFinder:findFile(path, "ojm")
			end
			if filePath then
				table.insert(newResources, filePath)
				self.aliases[name] = filePath
				break
			end
		end
	end
	self:loadResources(loaded, newResources)

	self:process()
end

---@param path string
function ResourceModel:loadResource(path)
	local fileType = self.fileFinder:getType(path)
	if fileType == "audio" then
		self.all_resources.loaded[path] = newSoundDataAsync(path, self.sample_gain)
	elseif fileType == "image" then
		self.all_resources.loaded[path] = newImageAsync(path)
	elseif fileType == "video" then
		self.all_resources.loaded[path] = newVideoAsync(path)
	elseif path:lower():find("%.ojm$") then
		local soundDatas = loadOjmAsync(path)
		if soundDatas then
			for name, soundData in pairs(soundDatas) do
				self.aliases[name] = path .. ":" .. name
				self.all_resources.loaded[path .. ":" .. name] = soundData
			end
		end
	end
end

---@param name string
---@return any?
function ResourceModel:getResource(name)
	local aliases = self.aliases
	local resources = self.resources
	return resources[aliases[name]]
end

---@param loaded table
---@param newResources table
function ResourceModel:loadResources(loaded, newResources)
	local new, old, all = table_util.array_update(newResources, loaded)

	for _, path in ipairs(old) do
		self.all_resources.loaded[path]:release()
		self.all_resources.loaded[path] = nil
	end

	self.all_resources.not_loaded = {}
	for _, path in ipairs(new) do
		self.all_resources.not_loaded[path] = true
	end
end

local isProcessing = false
ResourceModel.process = thread.coro(function(self)
	if isProcessing then
		return
	end
	isProcessing = true

	local path = next(self.all_resources.not_loaded)
	while path do
		self.all_resources.not_loaded[path] = nil
		self.all_resources.loading[path] = true

		self:loadResource(path)

		self.all_resources.loading[path] = nil

		path = next(self.all_resources.not_loaded)
	end
	self.callback()

	isProcessing = false
end)

function ResourceModel:unloadAudio()
	local fileFinder = self.fileFinder
	for path, resource in pairs(self.all_resources.loaded) do
		local fileType = fileFinder:getType(path)
		if not fileType or fileType == "audio" then
			resource:release()
			self.all_resources.loaded[path] = nil
		end
	end
end

return ResourceModel
