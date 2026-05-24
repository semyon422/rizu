local class = require("class")
local table_util = require("table_util")

---@class chart.sph.Metadata
---@operator call: chart.sph.Metadata
local Metadata = class()

local chartmeta_map = {
	{"title", "title"},
	{"artist", "artist"},
	{"name", "name"},
	{"creator", "creator"},
	{"source", "source"},
	{"level", "level"},
	{"tags", "tags"},
	{"audio", "audio_path"},
	{"background", "background_path"},
	{"preview", "preview_time"},
	{"input", "inputmode"},
}

local chartmeta_ignore = table_util.invert({
	"format",
	"duration",
	"tempo",
	"start_time",
})

local ordered_keys = {
	"title",
	"artist",
	"name",
	"creator",
	"source",
	"level",
	"tags",
	"audio",
	"background",
	"preview",
	"input",
}
local ordered_keys_map = table_util.invert(ordered_keys)

function Metadata:new()
	---@type {[string]: any}
	self.data = {}
end

---@param k string
---@param v any
function Metadata:set(k, v)
	self.data[k] = v
end

---@param k string
---@return any
function Metadata:get(k)
	return self.data[k]
end

---@return fun(): string, any
function Metadata:iter()
	local data = self.data

	---@type string[]
	local custom_keys = {}
	for key in pairs(data) do
		if not ordered_keys_map[key] then
			table.insert(custom_keys, key)
		end
	end
	table.sort(custom_keys)

	local keys = table_util.copy(ordered_keys)
	table_util.append(keys, custom_keys)

	return coroutine.wrap(function()
		for _, k in ipairs(keys) do
			coroutine.yield(k, data[k])
		end
	end)
end

---@param chartmeta sea.Chartmeta
function Metadata:fromChartmeta(chartmeta)
	---@type {[string]: true}
	local chartmeta_keys = {}

	for _, d in ipairs(chartmeta_map) do
		chartmeta_keys[d[2]] = true
		self:set(d[1], chartmeta[d[2]])
	end

	-- for k, v in pairs(chartmeta) do
	-- 	if not chartmeta_keys[k] and not chartmeta_ignore[k] then
	-- 		self:set(k, v)
	-- 	end
	-- end
end

---@return table
function Metadata:toChartmeta()
	local chartmeta = {
		format = "sphere",
		title = self.data.title,
		artist = self.data.artist,
		source = self.data.source,
		tags = self.data.tags,
		name = self.data.name,
		creator = self.data.creator,
		level = tonumber(self.data.level),
		audio_path = self.data.audio,
		background_path = self.data.background,
		preview_time = tonumber(self.data.preview),
		inputmode = self.data.input,
	}

	-- for k, v in pairs(self.data) do
	-- 	if not chartmeta[k] then
	-- 		chartmeta[k] = v
	-- 	end
	-- end

	return chartmeta
end

return Metadata
