local class = require("class")
local table_util = require("table_util")
local sql_util = require("rdb.sql_util")
local ChartmetaUserData = require("sea.chart.ChartmetaUserData")

---@class sea.ChartsRepo
---@operator call: sea.ChartsRepo
local ChartsRepo = class()

---@param models rdb.Models
---@param diffcalc_fields string[]
function ChartsRepo:new(models, diffcalc_fields)
	self.models = models
	self.diffcalc_fields = diffcalc_fields
end

---@return sea.Chartdiff[]
function ChartsRepo:getChartdiffs()
	return self.models.chartdiffs:select()
end

---@param id number
---@return sea.Chartdiff?
function ChartsRepo:getChartdiff(id)
	return self.models.chartdiffs:find({id = assert(id)})
end

---@param chartdiff_key sea.ChartdiffKey
---@return sea.Chartdiff?
function ChartsRepo:getChartdiffByChartdiffKey(chartdiff_key)
	return self.models.chartdiffs:find({
		hash = assert(chartdiff_key.hash),
		index = assert(chartdiff_key.index),
		modifiers = assert(chartdiff_key.modifiers),
		rate = assert(chartdiff_key.rate),
		mode = assert(chartdiff_key.mode),
	})
end

---@param chartdiff sea.Chartdiff
---@return sea.Chartdiff
function ChartsRepo:createChartdiff(chartdiff)
	return self.models.chartdiffs:create(chartdiff)
end

---@param chartdiff sea.Chartdiff
---@return sea.Chartdiff
function ChartsRepo:updateChartdiff(chartdiff)
	return self.models.chartdiffs:update(chartdiff, {id = assert(chartdiff.id)})[1]
end

---@param id integer
---@param previous string
---@param preview string
function ChartsRepo:repairNotesPreview(id, previous, preview)
	assert(preview ~= "", "repaired notes preview must not be empty")
	self.models.chartdiffs:update({notes_preview = preview}, {
		id = id,
		notes_preview = previous,
	})
end

---@param hash string
---@param index number
---@return sea.Chartdiff?
function ChartsRepo:selectDefaultChartdiff(hash, index)
	return self.models.chartdiffs:find({
		hash = assert(hash),
		index = assert(index),
		modifiers = {},
		rate = 1,
		mode = "mania",
	})
end

---@return integer
function ChartsRepo:countChartdiffs()
	return self.models.chartdiffs:count()
end

function ChartsRepo:deleteChartdiffs()
	self.models.chartdiffs:delete()
end

function ChartsRepo:deleteModifiedChartdiffs()
	self.models.chartdiffs:delete({
		"or",
		modifiers__ne = {},
		rate__ne = 1,
	})
end

---@param id integer
---@return sea.Chartdiff?
function ChartsRepo:deleteChartdiff(id)
	return self.models.chartdiffs:delete({id = assert(id)})[1]
end

---@param hash string
---@param index integer
---@return sea.Chartdiff[]
function ChartsRepo:deleteChartdiffsByHashIndex(hash, index)
	return self.models.chartdiffs:delete({
		hash = assert(hash),
		index = assert(index),
	})
end

---@param chartdiff sea.Chartdiff
---@param time integer
---@return sea.Chartdiff
function ChartsRepo:createUpdateChartdiff(chartdiff, time)
	local _chartdiff = self:getChartdiffByChartdiffKey(chartdiff)
	if not _chartdiff then
		chartdiff.created_at = time
		chartdiff.computed_at = time
		return self:createChartdiff(chartdiff)
	elseif not _chartdiff:equalsComputed(chartdiff) then
		chartdiff.id = _chartdiff.id
		chartdiff.computed_at = time
		return self:updateChartdiff(chartdiff)
	end
	return _chartdiff
end

---@return sea.Chartdiff[]
function ChartsRepo:getIncompleteChartdiffs()
	---@type rdb.Conditions
	local conds = {"or"}
	for _, field in ipairs(self.diffcalc_fields) do
		conds[field .. "__isnull"] = true
	end
	assert(next(conds))
	return self.models.chartdiffs:select(conds)
end

---@param field string
function ChartsRepo:resetDiffcalcField(field)
	assert(table_util.indexof(self.diffcalc_fields, field))
	self.models.chartdiffs:update({[field] = sql_util.NULL})
end

--------------------------------------------------------------------------------

---@return sea.Chartmeta[]
function ChartsRepo:getChartmetas()
	return self.models.chartmetas:select()
end

---@return sea.Chartmeta?
function ChartsRepo:getChartmeta(id)
	return self.models.chartmetas:find({id = assert(id)})
end

---@param hash string
---@param index integer
---@return sea.Chartmeta?
function ChartsRepo:getChartmetaByHashIndex(hash, index)
	return self.models.chartmetas:find({
		hash = assert(hash),
		index = assert(index),
	})
end

---@param chartmeta sea.Chartmeta
---@return sea.Chartmeta
function ChartsRepo:createChartmeta(chartmeta)
	return self.models.chartmetas:create(chartmeta)
end

---@param chartmeta sea.Chartmeta
---@return sea.Chartmeta
function ChartsRepo:updateChartmeta(chartmeta)
	return self.models.chartmetas:update(chartmeta, {id = assert(chartmeta.id)})[1]
end

---@return integer
function ChartsRepo:countChartmetas()
	return self.models.chartmetas:count()
end

function ChartsRepo:deleteChartmetas()
	self.models.chartmetas:delete()
end

---@param format sea.ChartFormat
function ChartsRepo:deleteChartmetasByFormat(format)
	self.models.chartmetas:delete({
		format = assert(format),
	})
end

---@return sea.Chartmeta[]
function ChartsRepo:getChartmetasMissingChartdiffs()
	return self.models.chartmetas_diffs_missing:select()
end

---@param chartmeta sea.Chartmeta
---@param time integer
---@return sea.Chartmeta
function ChartsRepo:createUpdateChartmeta(chartmeta, time)
	local _chartmeta = self:getChartmetaByHashIndex(chartmeta.hash, chartmeta.index)
	if not _chartmeta then
		chartmeta.created_at = time
		chartmeta.computed_at = time
		return self:createChartmeta(chartmeta)
	elseif not _chartmeta:equalsComputed(chartmeta) then
		chartmeta.id = _chartmeta.id
		chartmeta.computed_at = time
		return self:updateChartmeta(chartmeta)
	end
	return _chartmeta
end

---@param computed_at integer
---@param limit integer?
---@return sea.Chartmeta[]
function ChartsRepo:getChartmetasComputed(computed_at, limit)
	return self.models.chartmetas:select({
		computed_at__lt = assert(computed_at),
	}, {
		order = {"computed_at ASC"},
		limit = limit or 1,
	})
end

--------------------------------------------------------------------------------

---@param id integer
---@return sea.Chartplay?
function ChartsRepo:getChartplay(id)
	return self.models.chartplays:find({id = assert(id)})
end

---@return sea.Chartplay[]
function ChartsRepo:getChartplays()
	return self.models.chartplays:select()
end

---@return integer
function ChartsRepo:countChartplays()
	return self.models.chartplays:count()
end

---@param replay_hash string
---@return sea.Chartplay?
function ChartsRepo:getChartplayByReplayHash(replay_hash)
	return self.models.chartplays:find({replay_hash = assert(replay_hash)})
end

---@param chartplay sea.Chartplay
---@return sea.Chartplay
function ChartsRepo:createChartplay(chartplay)
	return self.models.chartplays:create(chartplay)
end

---@param chartplay sea.Chartplay
---@return sea.Chartplay
function ChartsRepo:updateChartplay(chartplay)
	return self.models.chartplays:update(chartplay, {id = assert(chartplay.id)})[1]
end

---@param computed_at integer
---@param state sea.ComputeState
---@return integer
function ChartsRepo:getChartplaysComputedCount(computed_at, state)
	return self.models.chartplays:count({
		computed_at__lte = assert(computed_at),
		compute_state = assert(state),
	})
end

---@param computed_at integer
---@param state sea.ComputeState
---@param limit integer?
---@return sea.Chartplay[]
function ChartsRepo:getChartplaysComputed(computed_at, state, limit)
	return self.models.chartplays:select({
		computed_at__lte = assert(computed_at),
		compute_state = assert(state),
	}, {
		order = {"computed_at ASC"},
		limit = limit or 1,
	})
end

---@param computed_at integer
---@param state sea.ComputeState
---@return integer
function ChartsRepo:getChartplaysComputedCount(computed_at, state)
	return self.models.chartplays:count({
		computed_at__lte = assert(computed_at),
		compute_state = assert(state),
	})
end

---@param chartmeta_key sea.ChartmetaKey
---@return sea.Chartplay[]
function ChartsRepo:getChartplaysForChartmeta(chartmeta_key)
	return self.models.chartplays_list:select({
		hash = assert(chartmeta_key.hash),
		index = assert(chartmeta_key.index),
	}, {order = {"rating DESC"}})
end

---@param chartdiff_key sea.ChartdiffKey
---@return sea.Chartplay[]
function ChartsRepo:getChartplaysForChartdiff(chartdiff_key)
	return self.models.chartplays_list:select({
		hash = assert(chartdiff_key.hash),
		index = assert(chartdiff_key.index),
		modifiers = assert(chartdiff_key.modifiers),
		rate = assert(chartdiff_key.rate),
		mode = assert(chartdiff_key.mode),
	}, {order = {"rating DESC"}})
end

---@param chartmeta_key sea.ChartmetaKey
---@return sea.Chartplay[]
function ChartsRepo:getBestChartplaysForChartmeta(chartmeta_key)
	return self.models.best_chartmeta_chartplays:select({
		hash = assert(chartmeta_key.hash),
		index = assert(chartmeta_key.index),
	})
end

---@param chartdiff_key sea.ChartdiffKey
---@return sea.Chartplay[]
function ChartsRepo:getBestChartplaysForChartdiff(chartdiff_key)
	return self.models.best_chartdiff_chartplays:select({
		hash = assert(chartdiff_key.hash),
		index = assert(chartdiff_key.index),
		modifiers = assert(chartdiff_key.modifiers),
		rate = assert(chartdiff_key.rate),
		mode = assert(chartdiff_key.mode),
	})
end

---@return sea.Chartplay[]
function ChartsRepo:getChartplaysMissingChartdiffs()
	return self.models.chartplays_list:select({
		chartdiff_id__isnull = true,
		chartmeta_id__isnotnull = true,
	})
end

---@param user_id integer
---@param limit integer
---@return sea.Chartplay[]
function ChartsRepo:getRecentChartplays(user_id, limit)
	return self.models.chartplays:select({
		user_id = assert(user_id),
	}, {
		limit = limit or 1,
		order = {"submitted_at DESC"},
	})
end

---@param user_id integer
---@return integer
function ChartsRepo:getUserChartplaysCount(user_id)
	return self.models.chartplays:count({
		user_id = assert(user_id),
	})
end

---@param user_id integer
---@return integer
function ChartsRepo:getUserChartmetasCount(user_id)
	return self.models.chartplays:count({
		user_id = assert(user_id),
	}, {
		group = {"hash", "`index`"},
	})
end

---@param user_id integer
---@return integer
function ChartsRepo:getUserChartdiffsCount(user_id)
	return self.models.chartplays:count({
		user_id = assert(user_id),
	}, {
		group = {"hash", "`index`", "modifiers", "rate", "mode"},
	})
end

--------------------------------------------------------------------------------

---@param chartmeta_user_data sea.ChartmetaUserData
function ChartsRepo:createChartmetaUserData(chartmeta_user_data)
	return self.models.chartmeta_user_datas:create(chartmeta_user_data)
end

---@param hash string
---@param index integer
---@param user_id integer
---@return sea.ChartmetaUserData?
function ChartsRepo:getUserChartmetaUserData(hash, index, user_id)
	return self.models.chartmeta_user_datas:find({
		hash = assert(hash),
		index = assert(index),
		user_id = assert(user_id),
	})
end

---@param chartmeta_user_data sea.ChartmetaUserData
---@return sea.ChartmetaUserData?
function ChartsRepo:updateChartmetaUserData(chartmeta_user_data)
	return self.models.chartmeta_user_datas:update(chartmeta_user_data, {id = assert(chartmeta_user_data.id)})
end

---@param chartmeta_user_data sea.ChartmetaUserData
---@return sea.ChartmetaUserData?
function ChartsRepo:updateChartmetaUserDataFull(chartmeta_user_data)
	local values = sql_util.null_keys(ChartmetaUserData.struct)
	table_util.copy(chartmeta_user_data, values)
	return self.models.chartmeta_user_datas:update(values, {id = assert(chartmeta_user_data.id)})[1]
end

return ChartsRepo
