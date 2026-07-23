local bit = require("bit")
local digest = require("digest")
local _7z = require("7z")
local class = require("class")
local Osr = require("chart.format.osu.Osr")
local Replay = require("sea.replays.Replay")
local ReplayCoder = require("sea.replays.ReplayCoder")
local Timings = require("sea.chart.Timings")
local Subtimings = require("sea.chart.Subtimings")
local TimingValuesFactory = require("sea.chart.TimingValuesFactory")
local Mods = require("bancho.constants.Mods")
local Grade = require("bancho.constants.Grade")
local ColumnsOrder = require("sea.chart.ColumnsOrder")

---@class sea.OsuReplayConverter
---@operator call: sea.OsuReplayConverter
local OsuReplayConverter = class()

---@param replay sea.Replay
---@param mania_events {[1]: integer, [2]: integer, [3]: boolean}[]
function OsuReplayConverter:fillReplayFrames(replay, mania_events)
	---@type rizu.ReplayFrame[]
	replay.frames = {}
	for i, event in ipairs(mania_events) do
		replay.frames[i] = {
			time = event[1] / 1000,
			event = {
				id = event[2],
				column = event[2],
				value = event[3],
			},
		}
	end
end

---@param events chart.osu.OsrEvent[]
---@return string
function OsuReplayConverter:encodeReplayEvents(events)
	local out = {}
	for i, event in ipairs(events) do
		out[i] = ("%s|%s|%s|%s,"):format(event[1], event[2], event[3], event[4])
	end
	return table.concat(out)
end

---@param replay_data string
---@return chart.osu.OsrEvent[]?
---@return string?
function OsuReplayConverter:decodeSubmissionReplayEvents(replay_data)
	local ok, uncomp_replay = pcall(_7z.decode_s, replay_data)
	if not ok then
		return nil, tostring(uncomp_replay)
	end

	---@type chart.osu.OsrEvent[]
	local events = {}
	for dt, x, y, km in uncomp_replay:gmatch("([^,^|]+)|([^,^|]+)|([^,^|]+)|([^,^|]+),") do
		events[#events + 1] = {
			tonumber(dt),
			tonumber(x),
			tonumber(y),
			tonumber(km),
		}
	end
	return events
end

---@param mods integer
---@return sea.ChartModifier[]
function OsuReplayConverter:getModifiers(mods)
	return {}
end

---@param mods integer
---@param inputmode string
---@return integer[]?
---@return string?
function OsuReplayConverter:getColumnsOrder(mods, inputmode)
	if bit.band(mods, Mods.RANDOM) ~= 0 then
		return nil, "random mod is not supported"
	end
	if bit.band(mods, Mods.MIRROR) ~= 0 then
		return ColumnsOrder(inputmode):mirror():export()
	end
	return nil
end

---@param mods integer
---@return number
function OsuReplayConverter:getRate(mods)
	if bit.band(mods, bit.bor(Mods.DOUBLETIME, Mods.NIGHTCORE)) ~= 0 then
		return 1.5
	elseif bit.band(mods, Mods.HALFTIME) ~= 0 then
		return 0.75
	end
	return 1
end

---@param mods integer
---@return sea.Subtimings
function OsuReplayConverter:getSubtimings(mods)
	if bit.band(mods, Mods.SCOREV2) ~= 0 then
		return Subtimings("scorev", 2)
	end
	return Subtimings("scorev", 1)
end

---@param replay sea.Replay|sea.Chartplay
---@param inputmode string?
---@return integer
function OsuReplayConverter:getModsFromReplay(replay, inputmode)
	local mods = 0
	if replay.rate == 1.5 then
		mods = bit.bor(mods, Mods.DOUBLETIME)
	elseif replay.rate == 0.75 then
		mods = bit.bor(mods, Mods.HALFTIME)
	end
	if replay.subtimings and replay.subtimings.name == "scorev" and replay.subtimings.data == 2 then
		mods = bit.bor(mods, Mods.SCOREV2)
	end
	if inputmode and replay.columns_order then
		local columns_order = ColumnsOrder(inputmode, replay.columns_order)
		if columns_order:getName() == "mirror" then
			mods = bit.bor(mods, Mods.MIRROR)
		else
			mods = bit.bor(mods, Mods.RANDOM)
		end
	end
	return mods
end

---@param replay_data string
---@param hash string
---@param index integer
---@param od number
---@param inputmode string
---@return sea.Replay?
---@return string?
---@return string?
function OsuReplayConverter:fromOsr(replay_data, hash, index, od, inputmode)
	local osr = Osr()
	local ok, err = pcall(osr.decode, osr, replay_data)
	if not ok then
		return nil, tostring(err)
	end

	local replay = Replay()
	replay.version = 2
	replay.hash = hash
	replay.index = index
	replay.modifiers = self:getModifiers(osr.mods)
	replay.rate = self:getRate(osr.mods)
	replay.mode = "mania"
	replay.nearest = true
	replay.tap_only = false
	replay.timings = Timings("osuod", od)
	replay.subtimings = self:getSubtimings(osr.mods)
	replay.timing_values = assert(TimingValuesFactory:get(replay.timings, replay.subtimings))
	replay.healths = nil
	replay.columns_order, err = self:getColumnsOrder(osr.mods, inputmode)
	if err then
		return nil, err
	end
	replay.custom = false
	replay.const = false
	replay.pause_count = 0
	replay.created_at = tonumber(osr:getTimestamp())
	replay.rate_type = replay.rate == 1 and "linear" or "exp"
	self:fillReplayFrames(replay, osr:decodeManiaEvents())

	local data = assert(ReplayCoder.encode(replay))
	return replay, data, digest.hash("md5", data, true)
end

---@param replay_data string
---@param hash string
---@param index integer
---@param od number
---@param inputmode string
---@param mods integer
---@param created_at integer
---@return sea.Replay?
---@return string?
---@return string?
function OsuReplayConverter:fromSubmissionReplay(replay_data, hash, index, od, inputmode, mods, created_at)
	local events, err = self:decodeSubmissionReplayEvents(replay_data)
	if not events then
		return nil, err
	end

	local replay = Replay()
	replay.version = 2
	replay.hash = hash
	replay.index = index
	replay.modifiers = self:getModifiers(mods)
	replay.rate = self:getRate(mods)
	replay.mode = "mania"
	replay.nearest = true
	replay.tap_only = false
	replay.timings = Timings("osuod", od)
	replay.subtimings = self:getSubtimings(mods)
	replay.timing_values = assert(TimingValuesFactory:get(replay.timings, replay.subtimings))
	replay.healths = nil
	replay.columns_order, err = self:getColumnsOrder(mods, inputmode)
	if err then
		return nil, err
	end
	replay.custom = false
	replay.const = false
	replay.pause_count = 0
	replay.created_at = created_at
	replay.rate_type = replay.rate == 1 and "linear" or "exp"

	local osr = Osr()
	osr.events = events
	self:fillReplayFrames(replay, osr:decodeManiaEvents())

	local data = assert(ReplayCoder.encode(replay))
	return replay, data, digest.hash("md5", data, true)
end

---@param judges integer[]
---@return integer, integer, integer, integer, integer, integer
function OsuReplayConverter:getHitCounts(judges)
	return judges[2] or 0, judges[4] or 0, judges[5] or 0, judges[1] or 0, judges[3] or 0, judges[6] or 0
end

---@param score table
---@return integer
function OsuReplayConverter:getScoreValue(score)
	if score.score then
		return score.score
	end
	local n300, n100, n50, ngeki, nkatu, nmiss = self:getHitCounts(score.judges or {})
	local total = n300 + n100 + n50 + ngeki + nkatu + nmiss
	if total == 0 then
		return 0
	end
	if score.subtimings and score.subtimings.name == "scorev" and score.subtimings.data == 2 then
		return math.floor(((n50 * 50 + n100 * 100 + nkatu * 200 + n300 * 300 + ngeki * 305) / (total * 305)) * 1000000 + 0.5)
	end
	return math.floor(((n50 * 50 + n100 * 100 + nkatu * 200 + (n300 + ngeki) * 300) / (total * 300)) * 1000000 + 0.5)
end

---@param score table
---@return integer
function OsuReplayConverter:getGradeValue(score)
	if score.grade then
		return score.grade
	end
	return Grade.fromString((score.getGrade and score:getGrade() or "F"):lower()).value
end

---@param replay sea.Replay|sea.Chartplay
---@return string
function OsuReplayConverter:toSubmissionReplay(replay)
	local osr = Osr()

	---@type [integer, integer, boolean][]
	local mania_events = {}
	for i, frame in ipairs(replay.frames) do
		mania_events[i] = {
			math.floor(frame.time * 1000 + 0.5),
			frame.event.column,
			not not frame.event.value,
		}
	end
	osr:encodeManiaEvents(mania_events)

	return _7z.encode_s(self:encodeReplayEvents(osr.events), osr.lzma_props)
end

---@param chartmeta sea.Chartmeta
---@param replay sea.Replay|sea.Chartplay
---@param user_name string
---@param score table
---@param score_id integer
---@return string
function OsuReplayConverter:toOsr(chartmeta, replay, user_name, score, score_id)
	local osr = Osr()
	osr.beatmap_hash = assert(replay.hash)
	osr.player_name = user_name
	osr.replay_hash = digest.hash("md5", user_name .. tostring(score_id) .. replay.hash, true)

	local n300, n100, n50, ngeki, nkatu, nmiss = self:getHitCounts(score.judges or replay.judges or {})
	osr._300 = n300
	osr._100 = n100
	osr._50 = n50
	osr.gekis = ngeki
	osr.katus = nkatu
	osr.misses = nmiss
	osr.score = self:getScoreValue(score)
	osr.combo = score.max_combo or replay.max_combo or 0
	osr.pfc = score.perfect and 1 or 0
	osr.mods = self:getModsFromReplay(replay, chartmeta.inputmode)
	osr.online_score_id = score_id
	osr:setTimestamp(replay.created_at)

	---@type [integer, integer, boolean][]
	local mania_events = {}
	for i, frame in ipairs(replay.frames) do
		mania_events[i] = {
			math.floor(frame.time * 1000 + 0.5),
			frame.event.column,
			not not frame.event.value,
		}
	end
	osr:encodeManiaEvents(mania_events)

	return osr:encode()
end

return OsuReplayConverter
