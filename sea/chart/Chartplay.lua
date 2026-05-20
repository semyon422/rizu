local valid = require("valid")
local table_util = require("table_util")
local erfunc = require("chart.scoring.erfunc")
local types = require("sea.shared.types")
local chart_types = require("sea.chart.types")
local ChartmetaKey = require("sea.chart.ChartmetaKey")
local ChartplayBase = require("sea.chart.ChartplayBase")
local ChartplayComputed = require("sea.chart.ChartplayComputed")

---@class sea.Chartplay: sea.ChartmetaKey, sea.ChartplayBase, sea.ChartplayComputed
---@operator call: sea.Chartplay
--- SERVER defined fields
---@field id integer
---@field user_id integer
---@field compute_state sea.ComputeState
---@field computed_at integer
---@field submitted_at integer
--- CLEINT defined fields
---@field online_id integer
--- METADATA
---@field replay_hash string
---@field pause_count integer
---@field created_at integer client-defined value
--- REQUIRED for computation: sea.ChartplayBase
--- METADATA not for computation: sea.ChartplayBase
--- COMPUTED: sea.ChartplayComputed
local Chartplay = ChartmetaKey + ChartplayBase + ChartplayComputed

Chartplay.struct = {
	replay_hash = types.md5hash,
	pause_count = types.count,
	created_at = types.time,
}
table_util.copy(ChartmetaKey.struct, Chartplay.struct)
table_util.copy(ChartplayBase.struct, Chartplay.struct)
table_util.copy(ChartplayComputed.struct, Chartplay.struct)

assert(#table_util.keys(Chartplay.struct) == 26)

local validate_chartplay = valid.compose(valid.struct(Chartplay.struct), chart_types.subtimings_pair)

---@return true?
---@return string|valid.Errors?
function Chartplay:validate()
	return validate_chartplay(self)
end

local keys = table_util.keys(Chartplay.struct)

---@param values sea.Chartplay
---@return boolean?
---@return string?
function Chartplay:equalsChartplay(values)
	return valid.equals(table_util.sub(self, keys), table_util.sub(values, keys))
end

---@return number
function Chartplay:getNormAccuracy()
	return erfunc.erf(0.032 / (self.accuracy * math.sqrt(2)))
end

---@return number
function Chartplay:getExScore()
	local judges = self.judges
	if #judges <= 1 then
		return 0
	end

	local total = 0
	for _, c in ipairs(judges) do
		total = total + c
	end

	return (2 * judges[1] + judges[2]) / (2 * total)
end

---@return string
function Chartplay:getGrade()
	local exscore = self:getExScore() * 9
	if exscore >= 8 then
		return "X"
	elseif exscore >= 7 then
		return "S"
	elseif exscore >= 6 then
		return "A"
	elseif exscore >= 5 then
		return "B"
	elseif exscore >= 4 then
		return "C"
	elseif exscore >= 3 then
		return "D"
	elseif exscore >= 2 then
		return "E"
	end
	return "F"
end

return Chartplay
