local class = require("class")
local sql_util = require("rdb.sql_util")
local table_util = require("table_util")
local Difftable = require("sea.difftables.Difftable")

---@class sea.DifftablesRepo
---@operator call: sea.DifftablesRepo
local DifftablesRepo = class()

---@param models rdb.Models
---@param transaction_mode rdb.TransactionMode?
function DifftablesRepo:new(models, transaction_mode)
	self.models = models
	self.transaction_mode = transaction_mode
end

---@return sea.Difftable[]
function DifftablesRepo:getDifftables()
	return self.models.difftables:select()
end

---@param id integer
---@return sea.Difftable?
function DifftablesRepo:getDifftable(id)
	return self.models.difftables:find({id = assert(id)})
end

---@param name string
---@return sea.Difftable?
function DifftablesRepo:getDifftableByName(name)
	return self.models.difftables:find({name = assert(name)})
end

---@param tag string
---@return sea.Difftable?
function DifftablesRepo:getDifftableByTag(tag)
	return self.models.difftables:find({tag = assert(tag)})
end

---@param difftable sea.Difftable
---@return sea.Difftable
function DifftablesRepo:createDifftable(difftable)
	return self.models.difftables:create(difftable)
end

---@param difftable sea.Difftable
---@return sea.Difftable
function DifftablesRepo:updateDifftable(difftable)
	return self.models.difftables:update(difftable, {id = assert(difftable.id)})[1]
end

---@param difftable sea.Difftable
---@return sea.Difftable
function DifftablesRepo:updateDifftableFull(difftable)
	local values = sql_util.null_keys(Difftable.struct)
	table_util.copy(difftable, values)
	return self.models.difftables:update(values, {id = assert(difftable.id)})[1]
end

---@param id integer
---@return sea.Difftable?
function DifftablesRepo:deleteDifftable(id)
	return self.models.difftables:delete({id = assert(id)})[1]
end

--------------------------------------------------------------------------------

---@return sea.DifftableChartmeta[]
function DifftablesRepo:getDifftableChartmetasAll()
	return self.models.difftable_chartmetas:select()
end

---@param hash string
---@param index integer
---@return sea.DifftableChartmeta[]
function DifftablesRepo:getDifftableChartmetasForChartmeta(hash, index)
	return self.models.difftable_chartmetas:select({
		hash = assert(hash),
		index = assert(index),
	})
end

---@param difftable_id integer
---@param include_deleted boolean?
---@param since integer?
---@param limit integer?
---@return sea.DifftableChartmeta[]
function DifftablesRepo:getDifftableChartmetas(difftable_id, include_deleted, since, limit)
	---@type rdb.Conditions
	local conds = {
		difftable_id = assert(difftable_id),
		is_deleted = false,
	}
	if since then
		conds.change_index__gte = since
	end
	if include_deleted then
		conds.is_deleted = nil
	end

	return self.models.difftable_chartmetas:select(conds, {
		order = {"change_index ASC"},
		limit = limit,
	})
end

---@param difftable_id integer
---@param include_deleted boolean?
---@param since integer?
---@return sea.DifftableChartmeta[]
function DifftablesRepo:getDifftableChartmetasFull(difftable_id, include_deleted, since)
	local dt_cms = self:getDifftableChartmetas(difftable_id, include_deleted, since)
	return self.models.difftable_chartmetas:preload(dt_cms, "user", "chartmeta")
end

---@param difftable_id integer
---@param hash string
---@param index integer
---@return sea.DifftableChartmeta?
function DifftablesRepo:getDifftableChartmeta(difftable_id, hash, index)
	return self.models.difftable_chartmetas:find({
		difftable_id = assert(difftable_id),
		hash = assert(hash),
		index = assert(index),
	})
end

---@param difftable_id integer
---@return integer
function DifftablesRepo:getNextChangeIndex(difftable_id)
	---@type sea.DifftableChartmeta?
	local dt_cm = self.models.difftable_chartmetas:find({
		difftable_id = assert(difftable_id),
	}, {
		order = {"change_index DESC"},
		limit = 1,
	})
	return (dt_cm and dt_cm.change_index or 0) + 1
end

---@param difftable_chartmetas sea.DifftableChartmeta[]
---@return sea.DifftableChartmeta[]
function DifftablesRepo:insertDifftableChartmetas(difftable_chartmetas)
	if not difftable_chartmetas[1] then
		return {}
	end

	self.models._orm:begin(self.transaction_mode)

	local change_index = self:getNextChangeIndex(difftable_chartmetas[1].difftable_id)

	for i, dt_cm in ipairs(difftable_chartmetas) do
		dt_cm.change_index = change_index + i - 1
	end
	local dt_cms = self.models.difftable_chartmetas:insert(difftable_chartmetas, "replace")

	self.models._orm:commit()
	return dt_cms
end

---@param difftable_chartmeta sea.DifftableChartmeta
---@return sea.DifftableChartmeta
function DifftablesRepo:createDifftableChartmeta(difftable_chartmeta)
	self.models._orm:begin(self.transaction_mode)

	difftable_chartmeta.change_index = self:getNextChangeIndex(difftable_chartmeta.difftable_id)
	local dt_cm = self.models.difftable_chartmetas:create(difftable_chartmeta)

	self.models._orm:commit()
	return dt_cm
end

---@param difftable_chartmeta sea.DifftableChartmeta
---@return sea.DifftableChartmeta
function DifftablesRepo:updateDifftableChartmeta(difftable_chartmeta)
	self.models._orm:begin(self.transaction_mode)

	difftable_chartmeta.change_index = self:getNextChangeIndex(difftable_chartmeta.difftable_id)
	local dt_cm = self.models.difftable_chartmetas:update(difftable_chartmeta, {id = assert(difftable_chartmeta.id)})[1]

	self.models._orm:commit()
	return dt_cm
end

---@param difftable_id integer
---@param hash string
---@param index integer
function DifftablesRepo:deleteDifftableChartmeta(difftable_id, hash, index)
	return self.models.difftable_chartmetas:delete({
		difftable_id = assert(difftable_id),
		hash = assert(hash),
		index = assert(index),
	})
end

return DifftablesRepo
