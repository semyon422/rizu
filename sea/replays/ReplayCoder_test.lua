local json = require("web.json")
local ReplayCoder = require("sea.replays.ReplayCoder")
local VirtualInputEvent = require("rizu.input.VirtualInputEvent")

local test = {}

---@param t testing.T
function test.v2(t)
	local replay = {
		version = 2,
		frames = {{
			time = 0,
			event = VirtualInputEvent(1, true, 1, {0, 0}),
		}},
	}

	local data = t:assert(ReplayCoder.encode(replay))
	if not data then
		return
	end

	t:tdeq(json.decode(data), {frames = "eJxjZEAARqZGBjQAAAkGAIY=", version = 2})

	local _replay = t:assert(ReplayCoder.decode(data))
	if not _replay then
		return
	end

	t:tdeq(_replay, replay)
end

---@param t testing.T
function test.v1(t)
	local replay = {
		version = 1,
		events = {{
			0, 1, true,
		}},
	}

	local data = t:assert(ReplayCoder.encode(replay))
	if not data then
		return
	end

	t:tdeq(json.decode(data), {events = "eJxjYkAHEgwAAGwAGw==", version = 1})

	local _replay = t:assert(ReplayCoder.decode(data))
	if not _replay then
		return
	end

	t:tdeq(_replay, replay)
end

return test
