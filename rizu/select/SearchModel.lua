local class = require("class")
local Observable = require("Observable")
local string_util = require("string_util")
local erfunc = require("chart.scoring.erfunc")
local Settings = require("rizu.config.Settings")

---@alias rizu.select.SearchOperator "eq"|"ne"|"gt"|"lt"|"gte"|"lte"

---@class rizu.select.NumberFieldConfig
---@field keys string[]
---@field field string
---@field inverse boolean?
---@field flip boolean?
---@field alias boolean? Not a real column, so it can't be used in the lamp query.
---@field transform (fun(self: rizu.select.SearchModel, value: string): number?)?

---@class rizu.select.SearchModel
---@operator call: rizu.select.SearchModel
local SearchModel = class()

---@param configModel sphere.ConfigModel
---@param settings rizu.config.Config
function SearchModel:new(configModel, settings)
	self.configModel = configModel
	self.settings = settings
	self.observable = Observable()
end

---@param observer rizu.select.SearchModelEventObserver|rizu.select.SearchModelEventReceiver
---@return util.Observer
function SearchModel:onChanged(observer)
	---@cast observer util.Observer|util.EventReceiver
	return self.observable:add(observer)
end

---@param observer util.Observer
---@return util.Observer?
function SearchModel:offChanged(observer)
	return self.observable:remove(observer)
end

---@return string
function SearchModel:getSearchString()
	return self.settings:getString(Settings.keys.select.filter_string)
end

---@param search_string string
function SearchModel:setSearchString(search_string)
	if search_string == self:getSearchString() then
		return
	end
	self.settings:setString(Settings.keys.select.filter_string, search_string)
	self.observable:send({type = "search_string_changed", search_string = search_string})
end

---@return string
function SearchModel:getLampString()
	return self.settings:getString(Settings.keys.select.lamp_string)
end

---@param lamp_string string
function SearchModel:setLampString(lamp_string)
	if lamp_string == self:getLampString() then
		return
	end
	self.settings:setString(Settings.keys.select.lamp_string, lamp_string)
	self.observable:send({type = "lamp_string_changed", lamp_string = lamp_string})
end

---@type rizu.select.NumberFieldConfig[]
local number_fields = {
	{
		keys = {"difficulty", "diff", "d"},
		field = "difficulty",
	},
	{
		keys = {"duration", "dur", "len", "l"},
		field = "duration",
		transform = function(self, v)
			local value = tonumber(v)
			if value then
				return value
			end
			local n, s = v:match("(%d+)(%a+)")
			if n and s == "m" then
				return tonumber(n) * 60
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
		alias = true,
		transform = function(self, v)
			local value = tonumber(v)
			if not value then
				return
			end
			return value / 100
		end,
	},
	{
		keys = {"miss", "m"},
		field = "miss_count",
	},
	{
		keys = {"accuracy", "acc", "a"},
		field = "accuracy",
		transform = function(self, v)
			local value = tonumber(v)
			if not value then
				return
			end
			return value / 1000
		end,
	},
	{
		keys = {"score", "s"},
		field = "accuracy",
		flip = true,
		transform = function(self, v)
			local value = tonumber(v)
			if not value then
				return
			end
			if value <= 0 then return 1000 end
			if value >= 10000 then return 0 end
			local window = self.settings:getNumber(Settings.keys.gameplay.rating_hit_timing_window)
			local accuracy = window / (erfunc.erfinv(value / 10000) * math.sqrt(2))
			if accuracy ~= accuracy or math.abs(accuracy) == math.huge then
				return 0
			end
			return accuracy
		end,
	},
}

---@type {[string]: rizu.select.NumberFieldConfig}
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

---@type {[string]: rizu.select.SearchOperator}
local operators = {
	["="] = "eq",
	["~="] = "ne",
	["!="] = "ne",
	[">"] = "gt",
	["<"] = "lt",
	[">="] = "gte",
	["<="] = "lte",
}

---@type {[rizu.select.SearchOperator]: rizu.select.SearchOperator}
local inverse_operators = {
	eq = "ne",
	ne = "eq",
	gt = "lte",
	lt = "gte",
	gte = "lt",
	lte = "gt",
}

---@type {[rizu.select.SearchOperator]: rizu.select.SearchOperator}
local flip_operators = {
	gt = "lt",
	lt = "gt",
	gte = "lte",
	lte = "gte",
}

---@param s string
---@param cond rdb.Conditions?
---@param numbers_only boolean? For the lamp query: skip plain text terms (their columns are ambiguous when joined) and alias fields.
---@return rdb.Conditions
function SearchModel:transformSearchString(s, cond, numbers_only)
	cond = cond or {}

	for _, _s in string_util.isplit(s, " ") do
		local key, operator, value = _s:match("^(.-)([=><~!]+)(.+)$")
		if _s == "!" or _s == "~" then
			cond.accuracy__isnull = true
		elseif key and operators[operator] then
			local config = fields_map[key]
			operator = operators[operator]
			if config and numbers_only and config.alias then
				config = nil
			end
			if config then
				local field = config.field
				if numbers_only and field == "difficulty" then
					field = self.settings:getChoice(Settings.keys.select.diff_column)
				end
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
					cond[field .. "__" .. operator] = value
				end
			end
		elseif not key and _s ~= "" and not numbers_only then
			---@type rdb.Conditions
			local _cond = {"or"}
			for _, k in ipairs(textFields) do
				_cond[k .. "__contains"] = _s
			end
			table.insert(cond, _cond)
		end
	end

	return cond
end

---@return sphere.ChartSearchFilter?
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

---@return rdb.Conditions
---@return rdb.Conditions?
function SearchModel:getConditions()
	local configs = self.configModel.configs
	local _select = configs.select

	local keys = Settings.keys.select
	local filterString = self:getSearchString()
	local lampString = self:getLampString()

	---@type rdb.Conditions
	local cond = {}

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

	local lamp = self:transformSearchString(lampString, nil, true)
	if next(lamp) == nil then
		-- Nothing usable was typed (plain text, unknown key). An empty condition would give every scored chart a lamp.
		lamp[{"0"}] = true
	end

	return self:transformSearchString(filterString, cond), lamp
end

return SearchModel
