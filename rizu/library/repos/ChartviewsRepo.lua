local table_util = require("table_util")
local sql_util = require("rdb.sql_util")
local ffi = require("ffi")
local class = require("class")
local QueryFragments = require("rizu.library.sql.QueryFragments")
local Model = require("rdb.Model")
local chartview_base = require("rizu.library.models.chartview_base")

---@class rizu.library.ChartviewsRepo.PackedQueryResult
---@field count integer
---@field items string Serialized `chartview_struct[]` bytes.
---@field maps rizu.library.ChartviewsRepo.IndexMaps

---@alias rizu.library.ChartviewsRepo.Mode "chartfile_sets"|"chartfiles"|"chartmetas"|"chartdiffs"|"chartplays"
---@alias rizu.library.ChartviewsRepo.IndexMaps {[string]: {[integer|string]: integer}}

---@class rizu.library.ChartviewsRepo.QueryParams
---@field order string[]?
---@field where rdb.Conditions
---@field lamp rdb.Conditions?
---@field difficulty string?
---@field primary_mode rizu.library.ChartviewsRepo.Mode?
---@field secondary_mode rizu.library.ChartviewsRepo.Mode?

---@class rizu.library.ChartviewsRepo
---@operator call: rizu.library.ChartviewsRepo
---@field models rdb.Models
---@field params rizu.library.ChartviewsRepo.QueryParams
---@field is_sync boolean
local ChartviewsRepo = class()

---@param models rdb.Models
function ChartviewsRepo:new(models)
	self.models = models
	self.params = {}
	self.is_sync = false
end

---@param is_sync boolean
function ChartviewsRepo:setSync(is_sync)
	self.is_sync = is_sync
end

----------------------------------------------------------------

ffi.cdef [[
	typedef struct {
		int32_t chartfile_id;
		int32_t chartfile_set_id;
		int32_t chartmeta_id;
		int32_t chartdiff_id;
		int32_t chartplay_id;
		bool lamp;
	} chartview_struct
]]

ChartviewsRepo.chartview_struct = ffi.typeof("chartview_struct")

---@param struct_array cdata
---@param count integer
---@param maps rizu.library.ChartviewsRepo.IndexMaps
---@return rizu.library.ChartviewsRepo.PackedQueryResult
function ChartviewsRepo:packResult(struct_array, count, maps)
	return {
		count = count,
		items = ffi.string(struct_array, ffi.sizeof("chartview_struct") * count),
		maps = maps,
	}
end

---@param t rizu.library.ChartviewsRepo.PackedQueryResult
---@return cdata struct_array
---@return integer count
---@return rizu.library.ChartviewsRepo.IndexMaps maps
function ChartviewsRepo:unpackResult(t)
	local count = t.count
	local items = ffi.new("chartview_struct[?]", count)
	ffi.copy(items, t.items, #t.items)
	return items, count, t.maps
end

---@param struct cdata
---@return rizu.library.IChartviewBase
function ChartviewsRepo:structToTable(struct)
	return {
		chartfile_id = struct.chartfile_id,
		chartfile_set_id = struct.chartfile_set_id,
		chartmeta_id = struct.chartmeta_id,
		chartdiff_id = struct.chartdiff_id,
		chartplay_id = struct.chartplay_id,
		lamp = struct.lamp,
	}
end

---@param chartfile_id integer
---@param id integer
---@return string
local function getCompositeIndexKey(chartfile_id, id)
	return ("%d:%d"):format(chartfile_id, id)
end

---@param model rdb.Model
---@param where rdb.Conditions
---@param options rdb.Options
---@return rizu.library.ChartviewsRepo.PackedQueryResult
function ChartviewsRepo:_fetchResult(model, where, options)
	local count_options = {
		columns = {"1"},
		group = options.group,
	}
	local count = model:count(where, count_options)

	local struct_array = ffi.new("chartview_struct[?]", count)
	local chartfile_id_to_global_index = {}
	local chartmeta_id_to_global_index = {}
	local chartdiff_id_to_global_index = {}
	local chartplay_id_to_global_index = {}
	local set_id_to_global_index = {}
	local chartfile_chartmeta_id_to_global_index = {}
	local chartfile_chartdiff_id_to_global_index = {}

	local c = 0
	for i, row in model:select_iter(where, options) do
		local entry = struct_array[c]
		entry.chartfile_id = row.chartfile_id
		entry.chartfile_set_id = row.chartfile_set_id
		entry.chartmeta_id = row.chartmeta_id or 0
		entry.chartdiff_id = row.chartdiff_id or 0
		entry.chartplay_id = row.chartplay_id or 0
		entry.lamp = sql_util.toboolean(row.lamp or 0)
		c = c + 1
		set_id_to_global_index[entry.chartfile_set_id] = c
		chartfile_id_to_global_index[entry.chartfile_id] = c
		chartmeta_id_to_global_index[entry.chartmeta_id] = c
		chartdiff_id_to_global_index[entry.chartdiff_id] = c
		chartplay_id_to_global_index[entry.chartplay_id] = c
		chartfile_chartmeta_id_to_global_index[getCompositeIndexKey(entry.chartfile_id, entry.chartmeta_id)] = c
		chartfile_chartdiff_id_to_global_index[getCompositeIndexKey(entry.chartfile_id, entry.chartdiff_id)] = c
	end

	return self:packResult(struct_array, c, {
		set_id_to_global_index = set_id_to_global_index,
		chartfile_id_to_global_index = chartfile_id_to_global_index,
		chartmeta_id_to_global_index = chartmeta_id_to_global_index,
		chartdiff_id_to_global_index = chartdiff_id_to_global_index,
		chartplay_id_to_global_index = chartplay_id_to_global_index,
		chartfile_chartmeta_id_to_global_index = chartfile_chartmeta_id_to_global_index,
		chartfile_chartdiff_id_to_global_index = chartfile_chartdiff_id_to_global_index,
	})
end

ChartviewsRepo.getCompositeIndexKey = getCompositeIndexKey

---@param params rizu.library.ChartviewsRepo.QueryParams
---@return rizu.library.ChartviewsRepo.PackedQueryResult
function ChartviewsRepo:queryAsync(params)
	if self.is_sync then
		self.params = params
		return self:query()
	end
	error("Use Library:queryAsync instead for threaded queries")
end

local LEVELS = {
	chartfile_sets = 1,
	chartfiles = 2,
	chartmetas = 3,
	chartdiffs = 4,
	chartplays = 5,
}

local LEVEL_GROUPS = {
	chartfile_sets = {"chartfile_set_id"},
	chartfiles = {"chartfile_id"},
	chartmetas = {"chartfile_id", "chartmeta_id"},
	chartdiffs = {"chartfile_id", "chartmeta_id", "chartdiff_id"},
	chartplays = {"chartplay_id"},
}

---@param params rizu.library.ChartviewsRepo.QueryParams
---@param mode rizu.library.ChartviewsRepo.Mode
---@param use_preview boolean
---@return string
function ChartviewsRepo:_buildViewSubquery(params, mode, use_preview)
	local level = LEVELS[mode]

	local columns = {
		QueryFragments.FIELDS_IDS,
		QueryFragments.FIELDS_CHARTFILE_SET,
		QueryFragments.FIELDS_CHARTFILE,
		QueryFragments.FIELDS_CHARTMETA,
		QueryFragments.FIELDS_CHARTMETA_USER_DATA,
		QueryFragments.FIELDS_CHARTDIFF,
	}

	if use_preview then
		table.insert(columns, QueryFragments.FIELDS_CHARTDIFF_PREVIEW)
	end

	local joins = {
		QueryFragments.JOINS_CHARTFILES_METAS_SETS,
	}

	table.insert(columns, QueryFragments.FIELDS_CHARTPLAY_STAT)
	table.insert(columns, QueryFragments.FIELDS_CHARTPLAY)

	if level <= LEVELS.chartmetas then
		table.insert(joins, "LEFT JOIN chartdiffs ON " .. QueryFragments.COND_CHARTDIFF_DEFAULT)
		table.insert(joins, "LEFT JOIN chartplays ON " .. QueryFragments.COND_CHARTPLAY)
	elseif level == LEVELS.chartdiffs then
		table.insert(joins, "LEFT JOIN chartdiffs ON " .. QueryFragments.COND_CHARTDIFF)
		table.insert(joins, "LEFT JOIN chartplays ON " .. QueryFragments.COND_CHARTPLAY_BY_MODE)
	elseif level == LEVELS.chartplays then
		table.insert(joins, "LEFT JOIN chartdiffs ON " .. QueryFragments.COND_CHARTDIFF)
		table.insert(joins, "INNER JOIN chartplays ON " .. QueryFragments.COND_CHARTPLAY_BY_MODS)
	end

	if params.lamp then
		table.insert(columns, QueryFragments.getLampField(params.lamp, false))
	end

	if params.difficulty then
		table.insert(columns, params.difficulty .. " AS difficulty")
	end

	local sql = "SELECT " .. table.concat(columns, ", ")
		.. " FROM chartfiles " .. table.concat(joins, " ")

	return sql
end

---@param params rizu.library.ChartviewsRepo.QueryParams
---@param mode rizu.library.ChartviewsRepo.Mode
---@param use_preview boolean
---@return rdb.Model
function ChartviewsRepo:_getDynamicViewModel(params, mode, use_preview)
	local subquery = self:_buildViewSubquery(params, mode, use_preview)
	return Model({
		subquery = subquery,
		types = chartview_base.types,
		from_db = chartview_base.from_db,
	}, self.models)
end

---@param mode rizu.library.ChartviewsRepo.Mode
---@param params rizu.library.ChartviewsRepo.QueryParams
---@param use_preview boolean
---@return string[]
function ChartviewsRepo:_getColumns(mode, params, use_preview)
	local level = LEVELS[mode]
	local columns = {
		level >= LEVELS.chartfiles and "chartfile_id" or "MIN(chartfile_id) AS chartfile_id",
		"chartfile_set_id",
		level >= LEVELS.chartmetas and "chartmeta_id" or "MIN(chartmeta_id) AS chartmeta_id",
		level >= LEVELS.chartdiffs and "chartdiff_id" or "MIN(chartdiff_id) AS chartdiff_id",
		level >= LEVELS.chartplays and "chartplay_id" or "MAX(chartplay_id) AS chartplay_id",
	}

	local base_columns = {
		"location_id", "set_is_file", "set_dir", "set_name", "set_modified_at",
		"chartfile_name", "modified_at", "hash",
		"`index`", "inputmode", "format", "chartmeta_timings", "chartmeta_healths",
		"title", "title_unicode", "artist", "artist_unicode", "name", "creator",
		"level", "source", "tags", "audio_path", "audio_offset", "background_path",
		"preview_time", "osu_beatmap_id", "osu_beatmapset_id",
		"tempo", "tempo_avg", "tempo_max", "tempo_min",
		"chartmeta_local_offset", "chartmeta_rating", "chartmeta_comment",
		"modifiers", "rate", "rate_type", "mode", "chartdiff_inputmode", "duration", "start_time",
		"notes_count", "judges_count", "long_notes_ratio", "note_types_count",
		"density_data", "sv_data", "enps_diff", "osu_diff", "msd_diff",
		"msd_diff_data", "msd_diff_rates", "user_diff", "user_diff_data",
	}

	if use_preview then
		table.insert(base_columns, "notes_preview")
	end

	if level < LEVELS.chartplays then
		columns = {
			level >= LEVELS.chartfiles and "chartfile_id" or "MIN(chartfile_id) AS chartfile_id",
			"chartfile_set_id",
			level >= LEVELS.chartmetas and "chartmeta_id" or "MIN(chartmeta_id) AS chartmeta_id",
			level >= LEVELS.chartdiffs and "chartdiff_id" or "MIN(chartdiff_id) AS chartdiff_id",
			level >= LEVELS.chartplays and "chartplay_id" or "MAX(chartplay_id) AS chartplay_id",
			"location_id", "set_is_file", "set_dir", "set_name", "set_modified_at",
			"chartfile_name",
			level >= LEVELS.chartfiles and "modified_at" or "MAX(modified_at) AS modified_at",
			"hash",
			"`index`", "inputmode", "format", "chartmeta_timings", "chartmeta_healths",
			"title", "title_unicode", "artist", "artist_unicode", "name", "creator",
			level >= LEVELS.chartmetas and "level" or "MAX(level) AS level",
			"source", "tags", "audio_path", "audio_offset", "background_path",
			"preview_time", "osu_beatmap_id", "osu_beatmapset_id",
			level >= LEVELS.chartmetas and "tempo" or "MAX(tempo) AS tempo",
			"tempo_avg", "tempo_max", "tempo_min",
			"chartmeta_local_offset", "chartmeta_rating", "chartmeta_comment",
			"modifiers", "rate", "mode", "chartdiff_inputmode",
			level >= LEVELS.chartdiffs and "duration" or "MAX(duration) AS duration",
			"start_time",
			level >= LEVELS.chartdiffs and "notes_count" or "MAX(notes_count) AS notes_count",
			"judges_count", "long_notes_ratio", "note_types_count",
			"density_data", "sv_data", "enps_diff", "osu_diff", "msd_diff",
			"msd_diff_data", "msd_diff_rates", "user_diff", "user_diff_data",
			"MIN(accuracy) AS accuracy",
			"MIN(miss_count) AS miss_count",
			"MAX(chartplay_created_at) AS chartplay_created_at",
			level >= LEVELS.chartdiffs and "difficulty" or "MAX(difficulty) AS difficulty",
		}
		if use_preview then
			table.insert(columns, "notes_preview")
		end
		if params.lamp then
			table.insert(columns, "MAX(lamp) AS lamp")
		end
	else
		table_util.append(columns, base_columns)
		table_util.append(columns, {
			"accuracy", "miss_count", "chartplay_created_at", "difficulty"
		})
		if params.lamp then
			table.insert(columns, "lamp")
		end
	end

	return columns
end

---@param mode rizu.library.ChartviewsRepo.Mode
---@param params rizu.library.ChartviewsRepo.QueryParams
---@return string[]
function ChartviewsRepo:_getSlimColumns(mode, params)
	local level = LEVELS[mode]
	local columns = {
		level >= LEVELS.chartfiles and "chartfile_id" or "MIN(chartfile_id) AS chartfile_id",
		"chartfile_set_id",
		level >= LEVELS.chartmetas and "chartmeta_id" or "MIN(chartmeta_id) AS chartmeta_id",
		level >= LEVELS.chartdiffs and "chartdiff_id" or "MIN(chartdiff_id) AS chartdiff_id",
		level >= LEVELS.chartplays and "chartplay_id" or "MAX(chartplay_id) AS chartplay_id",
	}

	if params.lamp then
		table.insert(columns, level < LEVELS.chartplays and "MAX(lamp) AS lamp" or "lamp")
	end

	return columns
end

---@return rizu.library.ChartviewsRepo.PackedQueryResult result
function ChartviewsRepo:query()
	local params = self.params
	---@type rizu.library.ChartviewsRepo.Mode
	local primary_mode = params.primary_mode or "chartmetas"
	---@type rizu.library.ChartviewsRepo.Mode
	local secondary_mode = params.secondary_mode or "chartmetas"

	-- Use finer mode for subquery to allow correct aggregation of underlying items
	local subquery_mode = LEVELS[secondary_mode] > LEVELS[primary_mode] and secondary_mode or primary_mode
	local model = self:_getDynamicViewModel(params, subquery_mode, false)

	local options = {
		columns = self:_getSlimColumns(primary_mode, params),
		order = params.order,
		group = LEVEL_GROUPS[primary_mode],
	}

	return self:_fetchResult(model, params.where, options)
end

---@param chartview rizu.library.IChartviewBase
---@return rizu.library.ChartviewsRepo.PackedQueryResult result
function ChartviewsRepo:getViews(chartview)
	local params = self.params
	---@type rizu.library.ChartviewsRepo.Mode
	local primary_mode = params.primary_mode or "chartmetas"
	---@type rizu.library.ChartviewsRepo.Mode
	local secondary_mode = params.secondary_mode or "chartmetas"

	local primary_level = LEVELS[primary_mode]
	local secondary_level = LEVELS[secondary_mode]

	local filter_level = math.min(primary_level, secondary_level)
	local group_mode = secondary_level >= primary_level and secondary_mode or primary_mode

	local model = self:_getDynamicViewModel(params, group_mode, false)

	local order = {
		"length(inputmode)",
		"chartdiff_inputmode",
		"inputmode",
		"difficulty",
		"name",
		"chartmeta_id",
		"chartdiff_id",
		"chartplay_id",
	}

	---@type rdb.Conditions
	local where = table_util.copy(params.where)
	if filter_level >= LEVELS.chartfile_sets then where.chartfile_set_id = chartview.chartfile_set_id end
	if filter_level >= LEVELS.chartfiles then where.chartfile_id = chartview.chartfile_id end
	if filter_level >= LEVELS.chartmetas then where.chartmeta_id = chartview.chartmeta_id end
	if filter_level >= LEVELS.chartdiffs then where.chartdiff_id = chartview.chartdiff_id end
	if filter_level >= LEVELS.chartplays then where.chartplay_id = chartview.chartplay_id end

	if secondary_mode == "chartplayviews" or secondary_level == LEVELS.chartplays then
		order = {"chartplay_id"}
	end

	local options = {
		columns = self:_getSlimColumns(group_mode, params),
		order = order,
		group = LEVEL_GROUPS[group_mode],
	}

	return self:_fetchResult(model, where, options)
end

---@param obj rizu.library.LocatedChartview
---@return rizu.library.LocatedChartview
function ChartviewsRepo:_fillRichData(obj)
	local hash, index = obj.hash, obj.index
	if hash and index then
		obj.difftable_chartmetas = self.models.difftable_chartmetas:select({
			hash = hash,
			index = index,
		})
	end
	return obj
end

---@param _chartview rizu.library.IChartviewBase
---@return rizu.library.Chartview?
function ChartviewsRepo:getChartview(_chartview)
	local chartfile_id = _chartview.chartfile_id
	local chartmeta_id = _chartview.chartmeta_id
	local chartdiff_id = _chartview.chartdiff_id
	local chartplay_id = _chartview.chartplay_id

	local params = self.params
	---@type rizu.library.ChartviewsRepo.Mode
	local mode = params.secondary_mode or params.primary_mode or "chartmetas"
	local model = self:_getDynamicViewModel(params, mode, true)
	local columns = self:_getColumns(mode, params, true)

	local options = {
		columns = columns,
		limit = 1,
		group = LEVELS[mode] < LEVELS.chartplays and LEVEL_GROUPS[mode] or nil,
	}

	---@type rdb.Conditions
	local where = {}
	---@type rizu.library.Chartview?
	local obj
	if chartplay_id and chartplay_id ~= 0 then
		where.chartfile_id = chartfile_id
		where.chartplay_id = chartplay_id
		obj = model:find(where, options)
	end
	if not obj and chartdiff_id and chartdiff_id ~= 0 then
		where.chartfile_id = chartfile_id
		where.chartplay_id = nil
		where.chartdiff_id = chartdiff_id
		obj = model:find(where, options)
	end
	if not obj and chartmeta_id and chartmeta_id ~= 0 then
		where.chartfile_id = chartfile_id
		where.chartdiff_id = nil
		where.chartmeta_id = chartmeta_id
		obj = model:find(where, options)
	end
	if not obj then
		where.chartfile_id = chartfile_id
		where.chartmeta_id = nil
		obj = model:find(where, options)
	end

	if obj then
		self:_fillRichData(obj)
	end

	return obj
end

return ChartviewsRepo
