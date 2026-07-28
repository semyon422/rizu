local class = require("class")

---@class ui.formatters.ReplayBaseFormatter
---@operator call: ui.formatters.ReplayBaseFormatter
local ReplayBaseFormatter = class()

---@param replay_base sea.ReplayBase?
---@param settings sphere.SettingsConfig
function ReplayBaseFormatter:new(replay_base, settings)
	self.replay_base = replay_base
	self.settings = settings
end

---@param replay_base sea.ReplayBase?
function ReplayBaseFormatter:setReplayBase(replay_base)
	self.replay_base = replay_base
end

local bms_alias = {"Easy", "Normal", "Hard", "Very hard"}

function ReplayBaseFormatter:getScoreSystem()
	local timings = self.replay_base.timings
	local subtimings = self.replay_base.subtimings

	if self.settings.replay_base.auto_timings then
		return "Auto Timings"
	end

	if not timings then
		return "No timings"
	end

	if timings.name == "sphere" then
		return "Rizu"
	elseif timings.name == "osuod" then
		---@cast subtimings -?
		return ("osu!mania V%i OD%i"):format(subtimings.data, timings.data)
	elseif timings.name == "etternaj" then
		return ("Etterna J%i"):format(timings.data)
	elseif timings.name == "quaver" then
		return "Quaver Standard"
	elseif timings.name == "bmsrank" then
		return ("LR2 %s"):format(bms_alias[timings.data])
	end

	return timings.name or "Unknown"
end

---@return boolean
function ReplayBaseFormatter:isConst()
	return self.replay_base.const
end

---@return string
function ReplayBaseFormatter:getColumnOrderType()
	local co = self.replay_base.columns_order

	if not co then
		return ""
	end

	local last = co[1]

	for _, v in ipairs(co) do
		if v > last then
			return "REORDERED"
		else
			last = v
		end
	end

	return "MIRROR"
end

---@return boolean
function ReplayBaseFormatter:isTapOnly()
	return self.replay_base.tap_only
end

return ReplayBaseFormatter
