local class = require("class")
local table_util = require("table_util")

---@class rizu.select.FilterModel
---@operator call: rizu.select.FilterModel
---@field combined_filters rdb.Conditions[]
local FilterModel = class()

---@param configModel sphere.ConfigModel
function FilterModel:new(configModel)
	self.configModel = configModel
	---@type rdb.Conditions[]
	self.combined_filters = {}
end

---@param group_name string
---@param filter_name string
---@return boolean?
function FilterModel:isActive(group_name, filter_name)
	---@type sphere.SelectedFilters
	local af = self.configModel.configs.select.selected_filters
	return af[group_name] and af[group_name][filter_name]
end

---@param group_name string
---@param filter_name string
---@param is_active boolean?
function FilterModel:setFilter(group_name, filter_name, is_active)
	---@type sphere.SelectedFilters
	local af = self.configModel.configs.select.selected_filters
	af[group_name] = af[group_name] or {}
	af[group_name][filter_name] = is_active
end

---@param group_name string
---@param filter_name string
---@return sphere.ChartConditionFilter?
function FilterModel:findFilter(group_name, filter_name)
	local filters = self.configModel.configs.filters.notechart
	for _, group in ipairs(filters) do
		if group.name == group_name then
			---@cast group sphere.ChartFilterGroup
			for _, filter in ipairs(group) do
				if filter.name == filter_name then
					return filter
				end
			end
		end
	end
end

function FilterModel:apply()
	---@type sphere.SelectedFilters
	local af = self.configModel.configs.select.selected_filters
	---@type rdb.Conditions[]
	local combined_filters = {}
	for group_name, group in pairs(af) do
		---@type rdb.Conditions
		local group_conds = {"or"}
		for filter_name, is_active in pairs(group) do
			local filter = self:findFilter(group_name, filter_name)
			if not filter then
				group[filter_name] = nil
			end
			if is_active and filter then
				table.insert(group_conds, table_util.copy(filter.conds))
			end
		end
		if group_conds[2] then
			table.insert(combined_filters, group_conds)
		end
	end
	self.combined_filters = combined_filters
end

return FilterModel
