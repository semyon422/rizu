local class = require("class")

---@class rizu.library.ChartplayAccuracy: rizu.engine.ScoreEngine.StoredAccuracies.Row
---@field chartplay_id integer

---@class rizu.library.repos.ChartplayAccuraciesRepo
---@operator call: rizu.library.repos.ChartplayAccuraciesRepo
local ChartplayAccuraciesRepo = class()

---@param models rdb.Models
function ChartplayAccuraciesRepo:new(models)
	self.models = models
end

---@param chartplay_id integer
---@return rizu.library.ChartplayAccuracy[]
function ChartplayAccuraciesRepo:getAccuracies(chartplay_id)
	return self.models.chartplay_accuracies:select({chartplay_id = assert(chartplay_id)})
end

---Replaces every stored accuracy of the chartplay with these.
---@param chartplay_id integer
---@param rows rizu.engine.ScoreEngine.StoredAccuracies.Row[]
function ChartplayAccuraciesRepo:setAccuracies(chartplay_id, rows)
	self.models.chartplay_accuracies:delete({chartplay_id = assert(chartplay_id)})
	if not rows[1] then
		return
	end
	---@type rizu.library.ChartplayAccuracy[]
	local values = {}
	for i, row in ipairs(rows) do
		values[i] = {
			chartplay_id = chartplay_id,
			timings = row.timings,
			subtimings = row.subtimings,
			accuracy = row.accuracy,
		}
	end
	self.models.chartplay_accuracies:insert(values)
end

return ChartplayAccuraciesRepo
