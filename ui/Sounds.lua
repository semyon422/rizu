local Path = require("Path")
local Sample = require("rizu.engine.audio.bass.Sample")

---@class ui.Sounds
local Sounds = {}
Sounds.sounds_dir = "resources/ui.sounds"
Sounds.sound_volume = 0.2
Sounds.cache = {} ---@type {[string]: rizu.audio.bass.Sample}

function Sounds.load() end

---@param name string
---@return rizu.audio.bass.Sample
function Sounds:loadSound(name)
	if Sounds.cache[name] then
		return Sounds.cache[name]
	end

	local data = assert(love.filesystem.read(tostring(Path(Sounds.sounds_dir) .. name .. ".wav")))
	local source = Sample(data)
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
