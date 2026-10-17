local SearchModel = require("rizu.select.SearchModel")
local Settings = require("rizu.config.Settings")
local FakeFilesystem = require("fs.FakeFilesystem")

local test = {}

---@param t testing.T
function test.no_implicit_mode_filter(t)
	local settings = Settings.createConfig(FakeFilesystem())
	settings:setString(Settings.keys.select.filter_string, "")
	settings:setString(Settings.keys.select.lamp_string, "")
	local search = SearchModel({configs = {select = {}, filters = {notechart = {}}}}, settings)
	local conditions, lamp = search:getConditions()
	t:tdeq(conditions, {})
	t:eq(lamp, nil)

	search:setSearchString("1osu")
	conditions = search:getConditions()
	t:eq(#conditions, 1)
	t:eq(conditions[1].inputmode__contains, "1osu")
end

---@param t testing.T
function test.search_string_event(t)
	local settings = Settings.createConfig(FakeFilesystem())
	local search = SearchModel({configs = {select = {}, filters = {notechart = {}}}}, settings)
	local events = {}
	search:onChanged(function(event)
		events[#events + 1] = event
	end)

	search:setSearchString("test")
	search:setSearchString("test")

	t:eq(search:getSearchString(), "test")
	t:tdeq(events, {{type = "search_string_changed", search_string = "test"}})
end

---@param t testing.T
function test.lamp_string_event(t)
	local settings = Settings.createConfig(FakeFilesystem())
	local search = SearchModel({configs = {select = {}, filters = {notechart = {}}}}, settings)
	local events = {}
	search:onChanged(function(event)
		events[#events + 1] = event
	end)

	search:setLampString("acc<20")
	search:setLampString("acc<20")

	t:eq(search:getLampString(), "acc<20")
	t:tdeq(events, {{type = "lamp_string_changed", lamp_string = "acc<20"}})
	local _, lamp = search:getConditions()
	t:eq(assert(lamp).accuracy__lt, 0.02)
end

---@param t testing.T
function test.lamp_string_ignores_text(t)
	local settings = Settings.createConfig(FakeFilesystem())
	local search = SearchModel({configs = {select = {}, filters = {notechart = {}}}}, settings)
	search:setLampString("a acc<20")
	local _, lamp = search:getConditions()
	lamp = assert(lamp)
	t:eq(#lamp, 0)
	t:eq(lamp.accuracy__lt, 0.02)

	search:setLampString("hello")
	_, lamp = search:getConditions()
	lamp = assert(lamp)
	t:eq(lamp.accuracy__lt, nil)
	t:eq(next(lamp) ~= nil, true) -- matches nothing instead of every scored chart
end

---@param t testing.T
function test.miss_uses_miss_count_column(t)
	local settings = Settings.createConfig(FakeFilesystem())
	local search = SearchModel({configs = {select = {}, filters = {notechart = {}}}}, settings)
	local conditions = search:transformSearchString("miss>4")
	t:eq(conditions.miss_count__gt, 4)
end

---@param t testing.T
function test.lamp_string_uses_real_columns(t)
	local settings = Settings.createConfig(FakeFilesystem())
	local search = SearchModel({configs = {select = {}, filters = {notechart = {}}}}, settings)
	local column = settings:getChoice(Settings.keys.select.diff_column)
	local conditions = search:transformSearchString("d>5 ln>10", nil, true)
	t:eq(conditions[column .. "__gt"], 5)
	t:eq(conditions.difficulty__gt, nil)
	t:eq(conditions.long_notes_ratio__gt, nil)
end

return test
