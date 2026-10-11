local class = require("class")
local json = require("json")
---@type {b64: fun(data: string): string, unb64: fun(data: string): string?}
local mime = require("mime")
local ReplayFrames = require("rizu.engine.replay.ReplayFrames")

---@class rizu.gameplay.ReplayData
---@field format string
---@field hash string
---@field index integer
---@field rate number
---@field frames string

---Local replays of one gamemode that does not save scores: the latest attempt per chart.
---@class rizu.gameplay.ReplayStore
---@operator call: rizu.gameplay.ReplayStore
local ReplayStore = class()

---@param fs fs.IFilesystem
---@param Base rizu.gameplay.ReplayBase Replay base class of the gamemode.
function ReplayStore:new(fs, Base)
	self.fs = fs
	self.Base = Base
	self.directory = "userdata/replays/" .. assert(Base.directory, "Gamemode has no local replays.")
end

---@param hash string
---@param index integer
---@return string
function ReplayStore:path(hash, index)
	assert(hash:match("^%x+$") and #hash == 32 and index >= 1 and index == math.floor(index), "invalid chart identity")
	return self.directory .. "/" .. hash .. "_" .. index .. ".json"
end

---@param session rizu.GameplaySession
---@return string
function ReplayStore:save(session)
	local re = session.rhythm_engine
	assert(session.play_type == "manual", "only manual attempts can be saved")
	local meta = re.chartmeta
	local path = self:path(meta.hash, meta.index)
	local base = self.Base()
	---@type rizu.gameplay.ReplayData
	local data = {
		format = base.format, hash = meta.hash, index = meta.index,
		rate = re.time_engine.timer.rate,
		frames = mime.b64(ReplayFrames.encode(session.replay_recorder:getFrames())),
	}
	assert(self.fs:createDirectory(self.directory))
	assert(self.fs:write(path, assert(json.encode(data))))
	return path
end

---@param hash string
---@param index integer
---@return rizu.gameplay.ReplayBase
---@return rizu.ReplayFrame[]
function ReplayStore:load(hash, index)
	local data = assert(self.fs:read(self:path(hash, index)), "No local " .. self.Base.directory .. " replay for this chart.")
	---@type rizu.gameplay.ReplayData
	local replay = assert(json.decode(data))
	assert(replay.hash == hash and replay.index == index, "Replay belongs to another chart.")
	local base = self.Base()
	base.format = replay.format
	base.rate = replay.rate
	assert(base:validate())
	local frames = ReplayFrames.decode(assert(mime.unb64(replay.frames)))
	local time = -math.huge
	for _, frame in ipairs(frames) do
		assert(frame.time == frame.time and math.abs(frame.time) < math.huge and frame.time >= time, "Invalid replay event time.")
		time = frame.time
		local event = frame.event
		assert(event:validate())
		assert(event.id >= 0 and event.id <= base.max_event_id and (event.column == 1 or event.column == 2), "Invalid input channel.")
		assert(event.value == nil or type(event.value) == "boolean", "Invalid input value.")
		assert(base:isValidEvent(event), "Invalid replay frame.")
		if event.pos then
			for _, v in ipairs(event.pos) do
				assert(v == v and math.abs(v) < math.huge, "Invalid replay position.")
			end
		end
	end
	return base, frames
end

return ReplayStore
