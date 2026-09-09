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

	settings:setString(Settings.keys.select.filter_string, "1osu")
	conditions = search:getConditions()
	t:eq(#conditions, 1)
	t:eq(conditions[1].inputmode__contains, "1osu")
end

return test
