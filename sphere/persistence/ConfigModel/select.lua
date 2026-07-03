---@class sphere.SelectConfig
---@field filterName string
---@field filterString string
---@field lampString string
---@field scoreFilterName string
---@field scoreSourceName string
---@field sortFunction string
---@field chartplay_id integer?
---@field selected_chartplay_id integer?
---@field selected_filters sphere.SelectedFilters

---@alias sphere.SelectedFilters {[string]: {[string]: boolean?}}

local _select = {
	collection = nil,
	location_id = nil,
	chartdiff_id = 1,
	chartmeta_id = 1,
	chartfile_id = 1,
	chartfile_set_id = 1,
	chartplay_id = 1,
	selected_chartplay_id = 1,
	searchMode = "filter",
	judgements = "soundsphere",
	scoreFilterName = "No filter",
	scoreSourceName = "local",
	filterName = "No filter",
	filterString = "",
	lampString = "",
	sortFunction = "title",
	selected_filters = {},
}

return _select
