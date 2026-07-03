local class = require("class")
local table_util = require("table_util")

---@class rizu.select.SelectionQueryBuilder
---@operator call: rizu.select.SelectionQueryBuilder
local SelectionQueryBuilder = class()

---@class rizu.select.SelectConfig
---@field sortFunction string

---@alias rizu.select.SelectionQueryParams rizu.library.ChartviewsRepo.QueryParams

---@param configModel sphere.ConfigModel
---@param sortModel rizu.select.SortModel
---@param searchModel rizu.select.SearchModel
---@param filterModel rizu.select.FilterModel
function SelectionQueryBuilder:new(configModel, sortModel, searchModel, filterModel)
	self.configModel = configModel
	self.sortModel = sortModel
	self.searchModel = searchModel
	self.filterModel = filterModel
end

---@param config rizu.select.SelectConfig The 'select' config from configModel
---@param collectionItem rizu.library.Collections.TreeNode? Current collection item
---@return rizu.select.SelectionQueryParams params
function SelectionQueryBuilder:build(config, collectionItem)
	local settings_select = self.configModel.configs.settings.select
	---@type rizu.select.SelectionQueryParams
	local params = {}

	local primary_mode = settings_select.primary_mode or "chartmetas"
	local secondary_mode = settings_select.secondary_mode or "chartmetas"

	-- Sorting
	local order = self.sortModel:getOrder(config.sortFunction)

	params.order = table_util.copy(order)
	table.insert(params.order, "chartmeta_id")

	-- Conditions (Search & Filters)
	local where, lamp = self.searchModel:getConditions()
	table_util.append(where, self.filterModel.combined_filters)

	-- Collection Filtering
	if collectionItem then
		local path = collectionItem.path
		if path then
			where.set_dir__startswith = path
		end
		where.location_id = collectionItem.location_id
	end

	params.where = where
	params.lamp = lamp
	params.difficulty = settings_select.diff_column
	params.primary_mode = primary_mode
	params.secondary_mode = secondary_mode

	return params
end

return SelectionQueryBuilder
