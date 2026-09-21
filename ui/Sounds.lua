local Path = require("Path")
local Sample = require("rizu.engine.audio.bass.Sample")
local Settings = require("rizu.config.Settings")

---@class ui.Sounds
local Sounds = {}
Sounds.sounds_dir = "resources/yi/sounds"
Sounds.cache = {} ---@type {[string]: rizu.audio.bass.Sample}
---@type rizu.config.Config?
Sounds.settings = nil

---@return number
function Sounds.getVolume()
	local volume = 1
	if Sounds.settings then
		local keys = Settings.keys.audio
		volume = volume * Sounds.settings:getNumber(keys.volume_master) * Sounds.settings:getNumber(keys.volume_ui)
	end
	return volume
end

---@param settings rizu.config.Config
function Sounds.load(settings)
	Sounds.settings = settings
	local keys = Settings.keys.audio
	local function updateVolume()
		for _, sound in pairs(Sounds.cache) do
			sound:setVolume(Sounds.getVolume())
		end
	end
	settings:subscribeNumber(keys.volume_master, updateVolume)
	settings:subscribeNumber(keys.volume_ui, updateVolume)
	updateVolume()
end

---@param name string
---@return rizu.audio.bass.Sample
function Sounds:loadSound(name)
	if Sounds.cache[name] then
		return Sounds.cache[name]
	end

	local data = assert(love.filesystem.read(tostring(Path(Sounds.sounds_dir) .. name .. ".wav")))
	local source = Sample(data)
	source:setVolume(Sounds.getVolume())
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
