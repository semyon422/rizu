local class = require("class")
local string_util = require("string_util")
local erfunc = require("libchart.erfunc")

---@class rizu.select.SearchModel
---@operator call: rizu.select.SearchModel
local SearchModel = class()

---@param configModel sphere.ConfigModel
function SearchModel:new(configModel)
	self.configModel = configModel
end

local number_fields = {
	{
		keys = {"difficulty", "diff", "d"},
		field = "difficulty",
	},
	{
		keys = {"duration", "dur", "len", "l"},
		field = "duration",
		transform = function(self, v)
			if tonumber(v) then
				return tonumber(v)
			end
			local n, s = v:match("(%d+)(%a+)")
			if s == "m" then
				return n * 60
			end
		end,
	},
	{
		keys = {"bpm", "b", "tempo", "t"},
		field = "tempo",
	},
	{
		keys = {"notes_count", "nc", "obj"},
		field = "notes_count",
	},
	{
		keys = {"level", "lv"},
		field = "level",
	},
	{
		keys = {"ln"},
		field = "long_notes_ratio",
		transform = function(self, v)
			if not tonumber(v) then
				return
			end
			v = tonumber(v)
			return v / 100
		end,
	},
	{
		keys = {"miss", "m"},
		field = "miss",
	},
	{
		keys = {"accuracy", "acc", "a"},
		field = "accuracy",
		transform = function(self, v)
			if not tonumber(v) then
				return
			end
			v = tonumber(v)
			return v / 1000
		end,
	},
	{
		keys = {"score", "s"},
		field = "accuracy",
		flip = true,
		transform = function(self, v)
			if not tonumber(v) then
				return
			end
			v = tonumber(v)
			if v <= 0 then return 1000 end
			if v >= 10000 then return 0 end
			local window = self.configModel.configs.settings.gameplay.ratingHitTimingWindow
			local accuracy = window / (erfunc.erfinv(v / 10000) * math.sqrt(2))
			if accuracy ~= accuracy or math.abs(accuracy) == math.huge then
				return 0
			end
			return accuracy
		end,
	},
}

local fields_map = {}
for _, config in ipairs(number_fields) do
	for _, k in ipairs(config.keys) do
		assert(not fields_map[k], "duplicate key: " .. k)
		fields_map[k] = config
	end
end

local textFields = {
	"hash",
	"chartfile_name",
	"artist",
	"title",
	"name",
	"source",
	"tags",
	"creator",
	"inputmode",
}

local operators = {
	["="] = "eq",
	["~="] = "ne",
	["!="] = "ne",
	[">"] = "gt",
	["<"] = "lt",
	[">="] = "gte",
	["<="] = "lte",
}

local inverse_operators = {
	eq = "ne",
	ne = "eq",
	gt = "lte",
	lt = "gte",
	gte = "lt",
	lte = "gt",
}

local flip_operators = {
	gt = "lt",
	lt = "gt",
	gte = "lte",
	lte = "gte",
}

---@param s string
---@param cond table?
---@return table
function SearchModel:transformSearchString(s, cond)
	cond = cond or {}

	for _, _s in string_util.isplit(s, " ") do
		local key, operator, value = _s:match("^(.-)([=><~!]+)(.+)$")
		if _s == "!" or _s == "~" then
			cond.accuracy__isnull = true
		elseif key and operators[operator] then
			local config = fields_map[key]
			operator = operators[operator]
			if config then
				if config.inverse then
					operator = inverse_operators[operator] or operator
				end
				if config.flip then
					operator = flip_operators[operator] or operator
				end
				if config.transform then
					value = config.transform(self, value)
				else
					value = tonumber(value)
				end
				if value then
					cond[config.field .. "__" .. operator] = value
				end
			end
		elseif not key and _s ~= "" then
			local _cond = {"or"}
			for _, k in ipairs(textFields) do
				_cond[k .. "__contains"] = _s
			end
			table.insert(cond, _cond)
		end
	end

	return cond
end

---@return table?
function SearchModel:getFilter()
	local configs = self.configModel.configs
	local filters = configs.filters
	local select = configs.select

	for _, filter in ipairs(filters.notechart) do
		if filter.name == select.filterName then
			return filter
		end
	end
end

---@return table
---@return table?
function SearchModel:getConditions()
	local configs = self.configModel.configs
	local settings = configs.settings
	local _select = configs.select

	local filterString, lampString = _select.filterString, _select.lampString

	local cond = {}

	if not settings.miscellaneous.showNonManiaCharts then
		table.insert(cond, {
			"or",
			inputmode__notin = {"1osu", "1taiko", "1fruits"},
			inputmode__isnull = true,
		})
	end

	local filter = self:getFilter()
	if filter then
		if filter.string then
			filterString = filterString .. " " .. filter.string
		end
		if filter.condition then
			table.insert(cond, filter.condition)
		end
	end

	if lampString == "" then
		return self:transformSearchString(filterString, cond)
	end

	return
		self:transformSearchString(filterString, cond),
		self:transformSearchString(lampString)
end

return SearchModel
