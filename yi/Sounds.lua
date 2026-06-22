local Path = require("Path")
local audio = require("audio")

---@class yi.Sounds
local Sounds = {}
Sounds.sounds_dir = "resources/yi/sounds"
Sounds.sound_volume = 0.2
Sounds.cache = {} ---@type {[string]: audio.Source}

function Sounds.load() end

---@param name string
---@return audio.Source
function Sounds:loadSound(name)
	if Sounds.cache[name] then
		return Sounds.cache[name]
	end

	local file_data = love.filesystem.newFileData(tostring(Path(Sounds.sounds_dir) .. name .. ".wav"))
	local sound_data = audio.SoundData(file_data:getFFIPointer(), file_data:getSize())
	local source = audio.newSource(sound_data)
	source:setVolume(Sounds.sound_volume)
	Sounds.cache[name] = source
	return source
end

local sound_play_time = {} ---@type {[string]: number}
local min_time = 0.05

---@param name string
function Sounds.play(name)
	local sound = Sounds.cache[name] or Sounds:loadSound(name)
	local last_time = sound_play_time[name] or -math.huge

	if love.timer.getTime() < last_time + min_time then
		return
	end

	sound_play_time[name] = love.timer.getTime()
	sound:stop()
	sound:play()
end

return Sounds
