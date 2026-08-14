local class = require("class")
local table_util = require("table_util")
local Settings = require("rizu.config.Settings")

---@class rizu.select.SelectionQueryBuilder
---@operator call: rizu.select.SelectionQueryBuilder
local SelectionQueryBuilder = class()

---@alias rizu.select.SelectionQueryParams rizu.library.ChartviewsRepo.QueryParams

---@param settings rizu.config.Config
---@param sortModel rizu.select.SortModel
---@param searchModel rizu.select.SearchModel
---@param filterModel rizu.select.FilterModel
function SelectionQueryBuilder:new(settings, sortModel, searchModel, filterModel)
	self.settings = settings
	self.sortModel = sortModel
	self.searchModel = searchModel
	self.filterModel = filterModel
end

---@param config sphere.SelectConfig The 'select' config from configModel
---@param collectionItem rizu.library.Collections.TreeNode? Current collection item
---@return rizu.select.SelectionQueryParams params
function SelectionQueryBuilder:build(config, collectionItem)
	local keys = Settings.keys.select
	---@type rizu.select.SelectionQueryParams
	local params = {}

	---@type rizu.library.ChartviewsRepo.Mode
	local primary_mode = self.settings:getChoice(keys.primary_mode)
	---@type rizu.library.ChartviewsRepo.Mode
	local secondary_mode = self.settings:getChoice(keys.secondary_mode)

	-- Sorting
	local order = self.sortModel:getOrder(self.settings:getString(keys.sort_function))

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
	params.difficulty = self.settings:getChoice(keys.diff_column)
	params.primary_mode = primary_mode
	params.secondary_mode = secondary_mode

	return params
end

return SelectionQueryBuilder
