local ChartfileReader = require("rizu.library.ChartfileReader")
local FakeFilesystem = require("fs.FakeFilesystem")
local Ifs = require("chart.format.iidx.Ifs")

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

---@param t testing.T
function test.ifs_reads_only_manifest_and_requested_file(t)
	local archive = Ifs.build({
		{path = "1234/1234.1", data = "chart data"},
		{path = "large.bin", data = string.rep("x", 1024 * 1024)},
	})
	local fs = FakeFilesystem()
	fs:createDirectory("data")
	fs:write("data/chart.ifs", archive)

	local bytes_read = 0
	local read_at = fs.readAt
	function fs:readAt(name, offset, size)
		bytes_read = bytes_read + size
		return read_at(self, name, offset, size)
	end

	t:eq(ChartfileReader.read(fs, "data/chart.ifs/1234/1234.1"), "chart data")
	t:assert(bytes_read < #archive / 10)
end

---@param t testing.T
function test.ifs_get_info_does_not_read_payload(t)
	local archive = Ifs.build({{path = "large.bin", data = string.rep("x", 1024 * 1024)}})
	local fs = FakeFilesystem()
	fs:createDirectory("data")
	fs:write("data/chart.ifs", archive)

	local bytes_read = 0
	local read_at = fs.readAt
	function fs:readAt(name, offset, size)
		bytes_read = bytes_read + size
		return read_at(self, name, offset, size)
	end

	local info = assert(ChartfileReader.getInfo(fs, "data/chart.ifs/large.bin"))
	t:eq(info.size, 1024 * 1024)
	t:assert(bytes_read < #archive / 10)
end

return test
