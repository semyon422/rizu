local ChartfileReader = require("rizu.library.ChartfileReader")
local FakeFilesystem = require("fs.FakeFilesystem")

local test = {}

---@param t testing.T
function test.invalid_ifs_returns_filename_error(t)
	local fs = FakeFilesystem()
	fs:createDirectory("data")
	fs:write("data/broken.ifs", "not an IFS archive")

	local data, err = ChartfileReader.read(fs, "data/broken.ifs/1234/1234.1")
	t:eq(data, nil)
	t:assert(err:find("data/broken.ifs", 1, true))
	t:assert(err:find("invalid IFS signature", 1, true))
	t:eq(ChartfileReader.getInfo(fs, "data/broken.ifs/1234/1234.1"), nil)
end

---@param t testing.T
function test.exists_checks_ifs_archive_without_parsing_it(t)
	local fs = FakeFilesystem()
	fs:createDirectory("data")
	fs:write("data/broken.ifs", "not an IFS archive")

	t:eq(ChartfileReader.exists(fs, "data/broken.ifs/1234/1234.1"), true)
	t:eq(ChartfileReader.exists(fs, "data/missing.ifs/1234/1234.1"), false)
end

return test
