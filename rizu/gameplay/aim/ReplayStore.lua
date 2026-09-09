local class = require("class")
local json = require("json")
---@type {b64: fun(data: string): string, unb64: fun(data: string): string?}
local mime = require("mime")
local ReplayFrames = require("rizu.engine.replay.ReplayFrames")

---@class rizu.aim.ReplayData
---@field format "rizu-sdvx-1"|"rizu-taiko-1"|"rizu-catch-1"|"rizu-aim-circles-1"|"rizu-aim-sliders-1"|"rizu-aim-spinners-1"|"rizu-aim-stacking-1"|"rizu-aim-tracking-1"
---@field hash string
---@field index integer
---@field rate number
---@field input_offset number
---@field frames string

---@class rizu.aim.ReplayStore
---@operator call: rizu.aim.ReplayStore
local ReplayStore = class()

ReplayStore.directory = "userdata/replays/aim"

---@param mode "aim"|"catch"|"taiko"|"sdvx"?
---@param fs fs.IFilesystem
function ReplayStore:new(fs, mode)
	self.fs = fs
	self.mode = mode or "aim"
	assert(self.mode == "aim" or self.mode == "catch" or self.mode == "taiko" or self.mode == "sdvx", "Invalid replay mode.")
	self.directory = "userdata/replays/" .. self.mode
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
	assert((self.mode == "sdvx" and re.sdvx_rules or self.mode == "taiko" and re.taiko_rules or self.mode == "catch" and re.catch_rules or self.mode == "aim" and re.aim_rules) and session.play_type == "manual", "only manual experimental attempts can be saved")
	local meta = re.chartmeta
	local path = self:path(meta.hash, meta.index)
	---@type rizu.aim.ReplayData
	local data = {
		format = self.mode == "sdvx" and "rizu-sdvx-1" or self.mode == "taiko" and "rizu-taiko-1" or self.mode == "catch" and "rizu-catch-1" or "rizu-aim-tracking-1", hash = meta.hash, index = meta.index,
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
	local data = assert(self.fs:read(self:path(hash, index)), "No local " .. self.mode .. " replay for this chart.")
	local replay = assert(json.decode(data))
	assert((self.mode == "sdvx") == (replay.format == "rizu-sdvx-1"), "Incompatible replay mode.")
	assert((self.mode == "taiko") == (replay.format == "rizu-taiko-1"), "Incompatible replay mode.")
	assert((self.mode == "catch") == (replay.format == "rizu-catch-1"), "Incompatible replay mode.")
	assert((replay.format == "rizu-sdvx-1" or replay.format == "rizu-taiko-1" or replay.format == "rizu-catch-1" or replay.format == "rizu-aim-circles-1" or replay.format == "rizu-aim-sliders-1" or replay.format == "rizu-aim-spinners-1" or replay.format == "rizu-aim-stacking-1" or replay.format == "rizu-aim-tracking-1") and replay.hash == hash and replay.index == index, "Incompatible experimental replay.")
	assert(type(replay.rate) == "number" and replay.rate >= 0.25 and replay.rate <= 4, "Invalid replay rate.")
	assert(type(replay.input_offset) == "number" and replay.input_offset == replay.input_offset and math.abs(replay.input_offset) < math.huge, "Invalid replay offset.")
	local frames = ReplayFrames.decode(assert(mime.unb64(replay.frames)))
	local time = -math.huge
	for _, frame in ipairs(frames) do
		assert(frame.time == frame.time and math.abs(frame.time) < math.huge and frame.time >= time, "Invalid replay event time.")
		time = frame.time
		local event = frame.event
		assert(event:validate())
		assert(event.id >= 0 and event.id <= (self.mode == "sdvx" and 12 or self.mode == "catch" and 6 or 4) and (event.column == 1 or event.column == 2), "Invalid experimental input channel.")
		assert(event.value == nil or type(event.value) == "boolean", "Invalid experimental input value.")
		if self.mode == "sdvx" and event.id >= 11 then
			assert(event.value == nil and event.pos and event.pos[2] == 0, "Invalid SDVX turn frame.")
		elseif self.mode ~= "aim" then
			assert(event.id >= 1 and type(event.value) == "boolean" and not event.pos, "Invalid action frame.")
		end
		if event.pos then
			for _, v in ipairs(event.pos) do
				assert(v == v and math.abs(v) < math.huge, "Invalid Aim position.")
			end
		end
	end
	return replay, frames
end

return ReplayStore
