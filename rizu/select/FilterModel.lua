local class = require("class")
local table_util = require("table_util")

---@class rizu.select.FilterModel
---@operator call: rizu.select.FilterModel
---@field combined_filters rizu.select.QueryCondition[]
local FilterModel = class()

---@alias rizu.select.QueryCondition {[any]: any}

---@class rizu.select.NotechartFilter
---@field name string
---@field conds rizu.select.QueryCondition

---@class rizu.select.NotechartFilterGroup
---@field name string
---@field [integer] rizu.select.NotechartFilter

---@param configModel sphere.ConfigModel
function FilterModel:new(configModel)
	self.configModel = configModel
	---@type rizu.select.QueryCondition[]
	self.combined_filters = {}
end

---@param group_name string
---@param filter_name string
---@return boolean?
function FilterModel:isActive(group_name, filter_name)
	local af = self.configModel.configs.select.selected_filters
	return af[group_name] and af[group_name][filter_name]
end

---@param group_name string
---@param filter_name string
---@param is_active boolean?
function FilterModel:setFilter(group_name, filter_name, is_active)
	local af = self.configModel.configs.select.selected_filters
	af[group_name] = af[group_name] or {}
	af[group_name][filter_name] = is_active
end

---@param group_name string
---@param filter_name string
---@return rizu.select.NotechartFilter?
function FilterModel:findFilter(group_name, filter_name)
	---@type rizu.select.NotechartFilterGroup[]
	local filters = self.configModel.configs.filters.notechart
	for _, group in ipairs(filters) do
		if group.name == group_name then
			for _, filter in ipairs(group) do
				if filter.name == filter_name then
					return filter
				end
			end
		end
	end
end

function FilterModel:apply()
	local af = self.configModel.configs.select.selected_filters
	---@type rizu.select.QueryCondition[]
	local combined_filters = {}
	for group_name, group in pairs(af) do
		---@type rizu.select.QueryCondition
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
