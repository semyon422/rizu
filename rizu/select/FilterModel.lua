local class = require("class")
local table_util = require("table_util")

---@class rizu.select.FilterModel
---@operator call: rizu.select.FilterModel
---@field combined_filters rdb.Conditions[]
local FilterModel = class()

local input_mode_fields = {
	["original input mode"] = "inputmode",
	["actual input mode"] = "chartdiff_inputmode",
}

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
---@return string[]
function FilterModel:getInputModes(group_name)
	assert(input_mode_fields[group_name], "unknown input mode filter group")
	local selected = self.configModel.configs.select.selected_filters[group_name] or {}
	local values = {}
	for value, active in pairs(selected) do
		if active then
			values[#values + 1] = value
		end
	end
	table.sort(values)
	return values
end

---@param group_name string
---@param values string[]
function FilterModel:setInputModes(group_name, values)
	assert(input_mode_fields[group_name], "unknown input mode filter group")
	local selected = {}
	for _, value in ipairs(values) do
		selected[value] = true
	end
	self.configModel.configs.select.selected_filters[group_name] = selected
end

---@param group_name string
---@return boolean
function FilterModel:hasActiveFilters(group_name)
	local group = self.configModel.configs.select.selected_filters[group_name]
	if not group then
		return false
	end
	for _, active in pairs(group) do
		if active then
			return true
		end
	end
	return false
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
	local group_names = {}
	for group_name in pairs(af) do
		group_names[#group_names + 1] = group_name
	end
	table.sort(group_names)
	for _, group_name in ipairs(group_names) do
		local group = af[group_name]
		---@type rdb.Conditions
		local group_conds = {"or"}
		local input_mode_field = input_mode_fields[group_name]
		if input_mode_field then
			local values = {}
			for value, is_active in pairs(group) do
				if is_active then values[#values + 1] = value end
			end
			table.sort(values)
			for _, value in ipairs(values) do
				local key_count = value:match("^(%d+)K$")
				local operation = key_count and "__startswith" or ""
				local filter_value = key_count and (key_count .. "key") or value
				table.insert(group_conds, {[input_mode_field .. operation] = filter_value})
			end
		else
			for filter_name, is_active in pairs(group) do
				local filter = self:findFilter(group_name, filter_name)
				if not filter then
					group[filter_name] = nil
				end
				if is_active and filter then
					table.insert(group_conds, table_util.copy(filter.conds))
				end
			end
		end
		if group_conds[2] then
			table.insert(combined_filters, group_conds)
		end
	end
	self.combined_filters = combined_filters
end

return FilterModel
