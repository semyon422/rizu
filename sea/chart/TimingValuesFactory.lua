local class = require("class")
local TimingValues = require("sea.chart.TimingValues")

local OsuManiaV1Timings = require("sea.timings.osumania.OsuManiaV1Timings_v4")
local OsuManiaV2Timings = require("sea.timings.osumania.OsuManiaV2Timings_v2")
local SoundsphereTimings = require("sea.timings.sphere.SoundsphereTimings_v1")
local QuaverTimings = require("sea.timings.quaver.QuaverTimings_v1")
local LunaticRaveTimings = require("sea.timings.bmsrank.LunaticRaveTimings_v2")
local IidxTimings = require("sea.timings.iidx.IidxTimings_v1")
local EtternaTimings = require("sea.timings.stepmania.EtternaTimings_v2")

---@class sea.TimingValuesFactory
---@operator call: sea.TimingValuesFactory
local TimingValuesFactory = class()

local err_msg = "invalid timings-subtimings pair"

---@param t sea.Timings
---@param st sea.Subtimings?
---@return sea.TimingValues?
---@return string?
function TimingValuesFactory:get(t, st)
	local tn, tv = t.name, t.data

	if tn == "arbitrary" then
		if not st then
			return nil, "undefined for arbitrary timings"
		end
		return nil, err_msg
	elseif tn == "sphere" then
		if not st then
			return SoundsphereTimings:getTimingValues()
		end
		return nil, err_msg
	elseif tn == "simple" then
		if not st then
			return TimingValues():setSimple(tv)
		end
		return nil, err_msg
	elseif tn == "osuod" then
		local stn, stv = "scorev", 1
		if st then
			stn, stv = st.name, st.data
		end
		if stn == "scorev" then
			if stv == 1 then
				return OsuManiaV1Timings:getTimingValues(tv)
			elseif stv == 2 then
				return OsuManiaV2Timings:getTimingValues(tv)
			end
		end
		return nil, err_msg
	elseif tn == "etternaj" then
		if not st then
			return EtternaTimings:getTimingValues(tv)
		end
		return nil, err_msg
	elseif tn == "quaver" then
		if not st then
			return QuaverTimings:getTimingValues()
		end
		return nil, err_msg
	elseif tn == "bmsrank" then
		if not st then
			return LunaticRaveTimings:getTimingValues()
		end
		return nil, err_msg
	elseif tn == "iidx" then
		if not st then
			return IidxTimings:getTimingValues()
		end
		return nil, err_msg
	elseif tn == "unknown" then
		if not st then
			return TimingValues():setSimple(0, 0)
		end
		return nil, err_msg
	end

	error("invalid timings object")
end

return TimingValuesFactory
