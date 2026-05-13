local class = require("class")
local audio = require("audio")
local rbtree = require("rbtree")

local Keyframe_mt = {}

---@param a table
---@param b table
---@return boolean
function Keyframe_mt.__eq(a, b)
	return a.time == b.time
end

---@param a table
---@param b table
---@return boolean
function Keyframe_mt.__lt(a, b)
	return a.time < b.time
end

---@param time number
---@return table
local function newKeyFrame(time)
	return setmetatable({
		time = time,
		sources = {},
	}, Keyframe_mt)
end

---@class rizu.editor.EditorAudioManager
---@operator call: rizu.editor.EditorAudioManager
local AudioManager = class()

---@param timer rizu.LocalTimer
---@param resourceModel sphere.ResourceModel
function AudioManager:new(timer, resourceModel)
	self.timer = timer
	self.resourceModel = resourceModel
end

AudioManager.time = 0

---@param key table
---@return number
local function exTime(key)
	return key.time
end

function AudioManager:load()
	self.tree = rbtree.new()

	self.sources = {}
	self.firstTime = 0
	self.lastTime = 0
end

function AudioManager:unload()
	local sources = {}
	for _, key in self.tree:iter() do
		for placedSource in pairs(key.sources) do
			sources[placedSource] = sources
		end
	end

	for placedSource in pairs(sources) do
		placedSource.source:stop()
		placedSource.source:release()
	end

	self:load()
end

---@param force boolean?
function AudioManager:update(force)
	local time = self.timer:getTime()
	if time == self.time and not force then
		return
	end
	self.time = time

	local isPlaying = self.timer.is_playing
	local forcePosition = not isPlaying or force

	local sources = self:getCurrentSources()

	for placedSource in pairs(self.sources) do
		if not sources[placedSource] then
			placedSource.source:stop()
			self.sources[placedSource] = nil
		end
	end

	local keysounds_volume = self.volume.keysounds * (self.volume.keysounds_format[self.format] or 1)
	for placedSource in pairs(sources) do
		if not self.sources[placedSource] then
			self.sources[placedSource] = true
		end
		placedSource.source:setRate(self.timer.rate)
		placedSource.source:setVolume(self.volume.master * keysounds_volume * placedSource.volume)
	end

	if forcePosition then
		for placedSource in pairs(self.sources) do
			placedSource.source:setPosition(time - placedSource.offset)
		end
	end

	if isPlaying then
		for placedSource in pairs(sources) do
			placedSource.source:play()
		end
	end
end

function AudioManager:play()
	local time = self.timer:getTime()
	for placedSource in pairs(self.sources) do
		placedSource.source:setPosition(time - placedSource.offset)
	end
end

function AudioManager:pause()
	for placedSource in pairs(self.sources) do
		placedSource.source:pause()
	end
end

---@return table
function AudioManager:getCurrentSources()
	local time = self.time

	local a, b = self.tree:findex(time, exTime)
	if a then
		return a.key.sources
	end
	if not b then
		return {}
	end

	if b.key.time > time then
		local prev = b:prev()
		return prev and prev.key.sources or {}
	end

	return b.key.sources
end

---@param time number
---@return table
function AudioManager:getNode(time)
	local tree = self.tree
	local n = tree:findex(time, exTime)
	if n then
		return n
	end

	n = tree:insert(newKeyFrame(time))

	local l = n:prev()
	if not l then
		return n
	end

	for source in pairs(l.key.sources) do
		n.key.sources[source] = true
	end

	return n
end

---@param placedSource table
function AudioManager:insert(placedSource)
	local startTime, endTime = placedSource.offset, placedSource.offset + placedSource.duration

	local a = self:getNode(startTime)
	local b = self:getNode(endTime)

	a.key.sources[placedSource] = true

	local n = a:next()
	while n and n.key < b.key do
		n.key.sources[placedSource] = true
		n = n:next()
	end
end

---@param placedSource table
function AudioManager:remove(placedSource)
	local n = self:getNode(placedSource.offset)

	while n and n.key.sources[placedSource] do
		n.key.sources[placedSource] = nil
		local _n = n
		n = n:next()
		if not next(_n.key.sources) then
			self.tree:remove_node(_n)
		end
	end
end

---@param chart ncdk2.Chart
---@param audioSettings table
function AudioManager:loadResources(chart, audioSettings)
	for _, note in chart.notes:iter() do
		local offset = note:getTime()
		if note.column ~= "audio" and note.data.sounds then
			for _, s in ipairs(note.data.sounds) do
				local soundData = self.resourceModel:getResource(s[1])
				if soundData then
					local mode = audioSettings.mode.secondary
					local duration = soundData:getDuration()
					self:insert({
						offset = offset,
						duration = duration,
						soundData = soundData,
						source = audio.newSource(soundData, mode),
						name = s[1],
						volume = s[2],
					})
					self.firstTime = math.min(self.firstTime, offset)
					self.lastTime = math.max(self.lastTime, offset + duration)
				end
			end
		end
	end
	-- self.firstTime = self.tree:min().key.time
	-- self.lastTime = self.tree:max().key.time
end

return AudioManager
