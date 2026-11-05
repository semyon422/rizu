local DifficultyLabels = require("rizu.library.DifficultyLabels")
local FakeFilesystem = require("fs.FakeFilesystem")
local json = require("json")

local test = {}

---@param t testing.T
function test.appends_lines(t)
	local fs = FakeFilesystem()
	fs:createDirectory("userdata")
	t:assert(DifficultyLabels.append(fs, {label = "exact"}))
	t:assert(DifficultyLabels.append(fs, {label = "overrated"}))
	local lines = {}
	for line in assert(fs:read(DifficultyLabels.path)):gmatch("[^\n]+") do
		table.insert(lines, json.decode(line).label)
	end
	t:tdeq(lines, {"exact", "overrated"})
end

---@param t testing.T
function test.unencodable_record_keeps_file(t)
	local fs = FakeFilesystem()
	fs:createDirectory("userdata")
	t:assert(DifficultyLabels.append(fs, {label = "exact"}))
	local ok, err = DifficultyLabels.append(fs, {value = 0 / 0})
	t:assert(not ok and err)
	t:eq(fs:read(DifficultyLabels.path), '{"label":"exact"}\n')
end

return test
