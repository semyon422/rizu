local ITimingValuesPreset = require("sea.timings.ITimingValuesPreset")
local TimingValues = require("sea.chart.TimingValues")
local Timings = require("sea.chart.Timings")
local Subtimings = require("sea.chart.Subtimings")
local odhp = require("chart.format.osu.odhp")

-- TODO: validate before release

---@class sea.OsuManiaV2Timings_v2: sea.ITimingValuesPreset
---@operator call: sea.OsuManiaV2Timings_v2
local OsuManiaV2Timings = ITimingValuesPreset + {}

---@param od number
function OsuManiaV2Timings:getBaseIntWindows(od)
	-- only 0.1x OD supported
	local od10 = od * 10
	assert(od10 == math.floor(od10))
	local od3 = math.floor(od * 3)

	local perfect_window = math.floor(od < 5 and 22.4 - 0.6 * od or 24.9 - 1.1 * od)

	return {
		perfect = perfect_window,
		great = 64 - od3,
		good = 97 - od3,
		ok = 127 - od3,
		meh = 151 - od3,
		miss = 188 - od3,
	}
end

---@param od number
function OsuManiaV2Timings:getNoteWindows(od)
	local w = self:getBaseIntWindows(od)
	return {
		perfect = w.perfect / 1000,
		great = w.great / 1000,
		good = w.good / 1000,
		ok = w.ok / 1000,
		meh = w.meh / 1000,
		miss = w.miss / 1000,
	}
end

---@param od number
function OsuManiaV2Timings:getTailWindows(od)
	local w = self:getBaseIntWindows(od)
	local mul = 1.5
	return {
		perfect = math.floor(w.perfect * mul) / 1000,
		great = math.floor(w.great * mul) / 1000,
		good = math.floor(w.good * mul) / 1000,
		ok = math.floor(w.ok * mul) / 1000,
		meh = math.floor(w.meh * mul) / 1000,
		miss = math.floor(w.miss * mul) / 1000,
	}
end

---@param od number
---@return sea.TimingValues
function OsuManiaV2Timings:getTimingValues(od)
	local w = self:getNoteWindows(od)
	local tw = self:getTailWindows(od)

	local a, b, c, d = -w.miss, -w.meh, w.ok, w.ok
	local ta, tb, tc, td = -tw.miss, -tw.meh, tw.ok, tw.ok

	local tvs = TimingValues()
	tvs.ShortNote = {hit = {b, c}, miss = {a, d}}
	tvs.LongNoteStart = {hit = {b, c}, miss = {a, d}}
	tvs.LongNoteEnd = {hit = {tb, tc}, miss = {ta, td}}

	return tvs
end

---@param tvs sea.TimingValues
---@return sea.Timings?
---@return sea.Subtimings?
function OsuManiaV2Timings:match(tvs)
	-- since windows in this version is rounded to 1ms they can't exactly match 0.1x OD
	-- returned values: _.0, _.4, _.7

	local od3 = (tvs.ShortNote.miss[1] * 1000 + 188)
	local floor_od3 = math.floor(od3 + 0.5)

	if math.abs(od3 - floor_od3) >= 1e-9 then
		return
	end

	local od = odhp.round_od(od3 / 3, 10)

	local _tvs = self:getTimingValues(od)
	if not _tvs:equals(tvs) then
		return
	end

	return Timings("osuod", od), Subtimings("scorev", 2)
end

return OsuManiaV2Timings
