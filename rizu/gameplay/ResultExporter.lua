local json = require("json")

---@class rizu.ResultExporter
local ResultExporter = {}

local replay_base_fields = {
	"modifiers",
	"rate",
	"mode",
	"nearest",
	"tap_only",
	"timings",
	"subtimings",
	"healths",
	"columns_order",
	"custom",
	"const",
	"rate_type",
	"timing_values",
}

---@param value any
---@param stack {[table]: true}
---@return any
local function serializeValue(value, stack)
	if value == nil or value == json.null then
		return json.null
	end

	local value_type = type(value)
	if value_type == "boolean" or value_type == "string" then
		return value
	elseif value_type == "number" then
		if value ~= value then
			return "NaN"
		elseif value == math.huge then
			return "Infinity"
		elseif value == -math.huge then
			return "-Infinity"
		end
		return value
	elseif value_type ~= "table" then
		error("cannot export JSON value of type " .. value_type)
	end

	if stack[value] then
		error("cannot export circular JSON value")
	end
	stack[value] = true

	local is_array = true
	local count = 0
	local max_index = 0
	---@diagnostic disable-next-line: no-unknown
	for key in pairs(value) do
		if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
			is_array = false
		else
			count = count + 1
			max_index = math.max(max_index, key)
		end
	end
	if is_array and count ~= max_index then
		is_array = false
	end

	---@type table<any, any>
	local result = is_array and json.array() or json.object()
	---@diagnostic disable-next-line: no-unknown
	for key, item in pairs(value) do
		if not is_array and type(key) ~= "string" then
			key = tostring(key)
		end
		result[key] = serializeValue(item, stack)
	end

	stack[value] = nil
	return result
end

---@param replay_base sea.ReplayBase?
---@return table
local function serializeReplayBase(replay_base)
	if not replay_base then
		return json.null
	end

	---@type table<string, any>
	local fields = {}
	for _, field in ipairs(replay_base_fields) do
		---@diagnostic disable-next-line: no-unknown
		local value = replay_base[field]
		fields[field] = value == nil and json.null or serializeValue(value, {})
	end
	return serializeValue(fields, {})
end

---@param chartplay sea.Chartplay?
---@param chartview rizu.library.LocatedChartview?
---@param replay_base sea.ReplayBase?
---@param score_engine rizu.ScoreEngine?
---@return string
function ResultExporter.serialize(chartplay, chartview, replay_base, score_engine)
	local payload = json.object({
		version = 1,
		score_id = serializeValue(chartplay and chartplay.id, {}),
		title = serializeValue(chartview and chartview.title, {}),
		artist = serializeValue(chartview and chartview.artist, {}),
		diff_name = serializeValue(chartview and chartview.name, {}),
		replay_base = serializeReplayBase(replay_base),
		hits = serializeValue(score_engine and score_engine.events or {}, {}),
		sequence = serializeValue(score_engine and score_engine.sequence or {}, {}),
	})
	return json.encode(payload, {indent = "\t"}) .. "\n"
end

---@param fs fs.IFilesystem
---@param path string
---@param chartplay sea.Chartplay?
---@param chartview rizu.library.LocatedChartview?
---@param replay_base sea.ReplayBase?
---@param score_engine rizu.ScoreEngine?
---@return boolean
---@return string?
function ResultExporter.export(fs, path, chartplay, chartview, replay_base, score_engine)
	local ok, data = pcall(
		ResultExporter.serialize,
		chartplay,
		chartview,
		replay_base,
		score_engine
	)
	if not ok then
		return false, data
	end
	return fs:write(path, data)
end

return ResultExporter
