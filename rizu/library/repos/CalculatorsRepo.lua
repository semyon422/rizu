local class = require("class")
local Calculators = require("rizu.library.Calculators")

---Rows of the plugin calculators and their play ratings, see rizu.library.Calculators.
---@class rizu.library.repos.CalculatorsRepo
---@operator call: rizu.library.repos.CalculatorsRepo
local CalculatorsRepo = class()

---@param models rdb.Models
function CalculatorsRepo:new(models)
	self.models = models
end

---Gives every calculator its row, and drops its values when its version changed.
---@param calculators rizu.library.Calculator[]
---@return {[integer]: rizu.library.Calculator} calculators By id.
function CalculatorsRepo:sync(calculators)
	local models = self.models
	---@type {[integer]: rizu.library.Calculator}
	local by_id = {}
	for _, calc in ipairs(calculators) do
		local row = models.calculators:find({name = calc.name})
		if not row then
			row = models.calculators:create({name = calc.name, version = calc.version})
		elseif row.version ~= calc.version then
			models.chart_difficulties:delete({calc_id = row.id})
			models.chartplay_ratings:delete({calc_id = row.id})
			models.calculators:update({version = calc.version}, {id = row.id})
		end
		by_id[row.id] = calc
	end
	return by_id
end

---Stores what the calculators that rate plays give this one. A calculator that fails gets NULL, so
---the play is not played again at every start.
---@param calculators rizu.library.Calculator[]
---@param chartplay_id integer
---@param ctx chart.DiffcalcContext? The played chart, with its modifiers and rate. nil stores the play as not rated.
---@param score_engine rizu.ScoreEngine? With the play's events.
---@return string[] errors
function CalculatorsRepo:ratePlay(calculators, chartplay_id, ctx, score_engine)
	---@type string[]
	local errors = {}
	---@type {chartplay_id: integer, calc_id: integer, key: integer, value: integer?}[]
	local rows = {}
	for id, calc in pairs(self:sync(calculators)) do
		if calc.computePlay then
			local ok, result = true, nil
			if ctx then
				ok, result = xpcall(function()
					return Calculators.toRows(calc, calc:computePlay(ctx, assert(score_engine), chartplay_id))
				end, debug.traceback)
			end
			if not ok then
				table.insert(errors, ("%s: %s"):format(calc.name, result))
			end
			for _, row in ipairs(ok and result or Calculators.toRows(calc, nil)) do
				table.insert(rows, {chartplay_id = chartplay_id, calc_id = id, key = row.key, value = row.value})
			end
		end
	end
	if rows[1] then
		self.models.chartplay_ratings:insert(rows, "replace")
	end
	return errors
end

---Ids of the chartplays that miss a rating of a calculator that rates plays.
---@param calculators rizu.library.Calculator[]
---@return integer[]
function CalculatorsRepo:getChartplaysMissingRatings(calculators)
	local by_id = self:sync(calculators)
	local ids = {}
	for id, calc in pairs(by_id) do
		if calc.computePlay then
			table.insert(ids, id)
		end
	end
	if not ids[1] then
		return {}
	end
	---@type integer[]
	local chartplay_ids = {}
	for _, row in ipairs(self.models.calculators.orm:query(([[
SELECT DISTINCT chartplays.id FROM chartplays CROSS JOIN calculators
WHERE calculators.id IN (%s) AND NOT EXISTS (
	SELECT 1 FROM chartplay_ratings WHERE chartplay_id = chartplays.id AND calc_id = calculators.id AND `key` = 0
)
ORDER BY chartplays.id
]]):format(table.concat(ids, ", ")))) do
		table.insert(chartplay_ids, tonumber(row.id))
	end
	return chartplay_ids
end

return CalculatorsRepo
