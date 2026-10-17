local FakeFilesystem = require("fs.FakeFilesystem")
local FolderStorage = require("sea.chart.storage.FolderStorage")

local test = {}

---@param t testing.T
function test.read_write_with_injected_fs(t)
	local fs = FakeFilesystem()
	fs:createDirectory("server-state/storages")
	fs:createDirectory("server-state/storages/charts")

	local storage = FolderStorage(fs, "server-state/storages/charts")
	local ok, err = storage:set("abc", "hello")
	t:eq(ok, true)
	t:eq(err, nil)
	t:eq(fs:read("server-state/storages/charts/abc"), "hello")
	t:eq(storage:get("abc"), "hello")

	t:assert(storage:set("abc", "replacement"))
	t:eq(storage:get("abc"), "replacement")
	for _, name in ipairs(fs:getDirectoryItems("server-state/storages/charts")) do
		t:eq(name:find(".tmp.", 1, true), nil)
	end
end

---@param t testing.T
function test.creates_parent_directories(t)
	local fs = FakeFilesystem()
	local storage = FolderStorage(fs, "server-state/storages/replays")

	local ok, err = storage:set("sub/def", "world")
	t:eq(ok, true)
	t:eq(err, nil)
	t:eq(fs:read("server-state/storages/replays/sub/def"), "world")
end

return test
