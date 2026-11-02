local class = require("class")
local DiffcalcContext = require("chart.difficulty.DiffcalcContext")
local BatchProcessor = require("rizu.library.tasks.BatchProcessor")
local Gamemode = require("sea.chart.Gamemode")
local CalculatorsRepo = require("rizu.library.repos.CalculatorsRepo")
local Calculators = require("rizu.library.Calculators")

---Rates the unmodded mania charts that miss a value of a plugin's calculator, see rizu.library.Calculators.
---@class rizu.library.tasks.CalculatorTask
---@operator call: rizu.library.tasks.CalculatorTask
local CalculatorTask = class()

---@param calculators rizu.library.Calculator[]
---@param models rdb.Models
---@param chartsRepo sea.ChartsRepo
---@param taskContext rizu.library.ITaskContext
---@param timer time.ITimer
---@param chartProvider rizu.library.ChartProvider
function CalculatorTask:new(calculators, models, chartsRepo, taskContext, timer, chartProvider)
	self.calculators = calculators
	self.models = models
	self.calculatorsRepo = CalculatorsRepo(models)
	self.chartsRepo = chartsRepo
	self.chartProvider = chartProvider
	self.batchProcessor = BatchProcessor(taskContext, timer)
end

function CalculatorTask:computeMissing()
	if not self.calculators[1] then
		return
	end
	local by_id = self.calculatorsRepo:sync(self.calculators)
	local ids = {}
	for id, calc in pairs(by_id) do
		if calc.compute then
			table.insert(ids, id)
		end
	end
	if not ids[1] then
		return
	end

	---@type {id: integer, hash: string, index: integer, calc_ids: integer[]}[]
	local items = {}
	local last ---@type {id: integer, hash: string, index: integer, calc_ids: integer[]}?
	for _, row in ipairs(self.models.calculators.orm:query(([[
SELECT chartmetas.id, chartmetas.hash, chartmetas.`index`, calculators.id AS calc_id
FROM chartmetas CROSS JOIN calculators
WHERE chartmetas.mode = %d AND calculators.id IN (%s) AND NOT EXISTS (
	SELECT 1 FROM chart_difficulties
	WHERE chart_id = chartmetas.id AND calc_id = calculators.id AND `key` = 0 AND rate = 1000
)
ORDER BY chartmetas.hash, chartmetas.`index`
]]):format(Gamemode:encode("mania"), table.concat(ids, ", ")))) do
		local id = tonumber(row.id) --[[@as integer]]
		if not last or last.id ~= id then
			last = {id = id, hash = row.hash, index = tonumber(row.index), calc_ids = {}}
			table.insert(items, last)
		end
		table.insert(last.calc_ids, tonumber(row.calc_id))
	end

	self.batchProcessor:process(items, "difficulty", #items, function(item)
		---@type {[integer]: rizu.library.Calculators.Row[]}
		local values = {}
		-- A chart that fails gets NULL too, so it isn't decoded again at every start.
		local ok, err = xpcall(self.computeValues, debug.traceback, self, item, by_id, values)
		---@type {chart_id: integer, calc_id: integer, key: integer, rate: integer, value: integer?}[]
		local rows = {}
		for _, calc_id in ipairs(item.calc_ids) do
			for _, row in ipairs(values[calc_id] or Calculators.toRows(by_id[calc_id], nil)) do
				table.insert(rows, {chart_id = item.id, calc_id = calc_id, key = row.key, rate = 1000, value = row.value})
			end
		end
		self.models.chart_difficulties:insert(rows, "replace")
		assert(ok, err)
		return item.hash
	end)
end

---@param item {id: integer, hash: string, index: integer, calc_ids: integer[]}
---@param by_id {[integer]: rizu.library.Calculator}
---@param values {[integer]: rizu.library.Calculators.Row[]} Filled by calculator id.
function CalculatorTask:computeValues(item, by_id, values)
	local charts, err = self.chartProvider(item.hash)
	if not charts then
		error("getChartsByHash error (" .. item.hash .. "): " .. tostring(err))
	end
	local chart = assert(charts[item.index], "no chart " .. item.index .. " in " .. item.hash)
	chart.layers.main:toAbsolute()
	local chartmeta = assert(self.chartsRepo:getChartmetaByHashIndex(item.hash, item.index))
	local chartdiff = self.chartsRepo:selectDefaultChartdiff(item.hash, item.index) or {}
	local ctx = DiffcalcContext(chartdiff, chart, 1)
	for _, calc_id in ipairs(item.calc_ids) do
		local calc = by_id[calc_id]
		values[calc_id] = Calculators.toRows(calc, calc:compute(ctx, chartmeta))
	end
end

return CalculatorTask
