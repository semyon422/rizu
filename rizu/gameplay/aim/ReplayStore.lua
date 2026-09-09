local class = require("class")
local json = require("json")
---@type {b64: fun(data: string): string, unb64: fun(data: string): string?}
local mime = require("mime")
local ReplayFrames = require("rizu.engine.replay.ReplayFrames")

---@class rizu.aim.ReplayData
---@field format "rizu-aim-circles-1"|"rizu-aim-sliders-1"
---@field hash string
---@field index integer
---@field rate number
---@field input_offset number
---@field frames string

---@class rizu.aim.ReplayStore
---@operator call: rizu.aim.ReplayStore
local ReplayStore = class()

ReplayStore.directory = "userdata/replays/aim"

---@param fs fs.IFilesystem
function ReplayStore:new(fs)
	self.fs = fs
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
	assert(re.aim_rules and session.play_type == "manual", "only manual Aim attempts can be saved")
	local meta = re.chartmeta
	local path = self:path(meta.hash, meta.index)
	---@type rizu.aim.ReplayData
	local data = {
		format = "rizu-aim-sliders-1", hash = meta.hash, index = meta.index,
		rate = re.time_engine.timer.rate, input_offset = re.logic_offset,
		frames = mime.b64(ReplayFrames.encode(session.replay_recorder:getFrames())),
	}
	assert(self.fs:createDirectory(self.directory))
	assert(self.fs:write(path, assert(json.encode(data))))
	return path
end

---@param hash string
---@param index integer
---@return rizu.aim.ReplayData
---@return rizu.ReplayFrame[]
function ReplayStore:load(hash, index)
	local data = assert(self.fs:read(self:path(hash, index)), "No local Aim replay for this chart.")
	local replay = assert(json.decode(data))
	assert((replay.format == "rizu-aim-circles-1" or replay.format == "rizu-aim-sliders-1") and replay.hash == hash and replay.index == index, "Incompatible Aim replay.")
	assert(type(replay.rate) == "number" and replay.rate >= 0.25 and replay.rate <= 4, "Invalid replay rate.")
	assert(type(replay.input_offset) == "number" and replay.input_offset == replay.input_offset and math.abs(replay.input_offset) < math.huge, "Invalid replay offset.")
	local frames = ReplayFrames.decode(assert(mime.unb64(replay.frames)))
	local time = -math.huge
	for _, frame in ipairs(frames) do
		assert(frame.time == frame.time and math.abs(frame.time) < math.huge and frame.time >= time, "Invalid replay event time.")
		time = frame.time
		local event = frame.event
		assert(event:validate())
		assert(event.id >= 0 and event.id <= 4 and (event.column == 1 or event.column == 2), "Invalid Aim input channel.")
		assert(event.value == nil or type(event.value) == "boolean", "Invalid Aim input value.")
		if event.pos then
			for _, v in ipairs(event.pos) do
				assert(v == v and math.abs(v) < math.huge, "Invalid Aim position.")
			end
		end
	end
	return replay, frames
end

return ReplayStore
