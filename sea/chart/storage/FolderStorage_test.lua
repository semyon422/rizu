local FakeFilesystem = require("fs.FakeFilesystem")
local FolderStorage = require("sea.chart.storage.FolderStorage")

local test = {}

---@param t testing.T
function test.read_write_with_injected_fs(t)
	local fs = FakeFilesystem()
	fs:createDirectory("storages")
	fs:createDirectory("storages/charts")

	local storage = FolderStorage(fs, "storages/charts")
	local ok, err = storage:set("abc", "hello")
	t:eq(ok, true)
	t:eq(err, nil)
	t:eq(fs:read("storages/charts/abc"), "hello")
	t:eq(storage:get("abc"), "hello")
end

---@param t testing.T
function test.creates_parent_directories(t)
	local fs = FakeFilesystem()
	local storage = FolderStorage(fs, "storages/replays")

	local ok, err = storage:set("sub/def", "world")
	t:eq(ok, true)
	t:eq(err, nil)
	t:eq(fs:read("storages/replays/sub/def"), "world")
end

return test
