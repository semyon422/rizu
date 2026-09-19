local ITimingValuesPreset = require("sea.timings.ITimingValuesPreset")
local TimingValues = require("sea.chart.TimingValues")
local Timings = require("sea.chart.Timings")

---@class sea.IidxTimings_v1: sea.ITimingValuesPreset
---@operator call: sea.IidxTimings_v1
local IidxTimings = ITimingValuesPreset + {}

local bad_window = 0.250

---@return sea.TimingValues
function IidxTimings:getTimingValues()
	local tvs = TimingValues()
	tvs.ShortNote = {hit = {-bad_window, bad_window}, miss = {-bad_window, bad_window}}
	tvs.LongNoteStart = {hit = {-bad_window, bad_window}, miss = {-bad_window, bad_window}}
	-- Charge-note heads and tails use the same outer ±250 ms interaction range
	-- in the basic IIDX model. IidxScore owns the judgment within that range.
	tvs.LongNoteEnd = {hit = {-bad_window, bad_window}, miss = {-bad_window, bad_window}}
	return tvs
end

---@param tvs sea.TimingValues
---@return sea.Timings?
function IidxTimings:match(tvs)
	if not self:getTimingValues():equals(tvs) then
		return
	end
	return Timings("iidx")
end

return IidxTimings
