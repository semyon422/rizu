local Ifs = require("chart.format.iidx.Ifs")

---@class rizu.library.ChartfileReader
local ChartfileReader = {}

---@param path string
---@return string? archive_path
---@return string? chart_path
function ChartfileReader.splitArchivePath(path)
	local archive_path, chart_path = path:match("^(.-%.ifs)/(.*)$")
	return archive_path, chart_path
end

---@param path string
---@return boolean
function ChartfileReader.isArchivePath(path)
	return ChartfileReader.splitArchivePath(path) ~= nil
end

---Checks the backing filesystem entry without opening a container.
---For an internal IFS path, this only verifies that the outer archive exists.
---@param fs fs.IFilesystem
---@param path string
---@return boolean
function ChartfileReader.exists(fs, path)
	local archive_path = ChartfileReader.splitArchivePath(path)
	return fs:getInfo(archive_path or path) ~= nil
end

---@param fs fs.IFilesystem
---@param archive_path string
---@param header string
---@return chart.iidx.IfsArchive
local function parseArchive(fs, archive_path, header)
	assert(header:sub(1, 4) == "\108\173\143\137", "invalid IFS signature")
	assert(#header >= 20, "truncated IFS header")
	local version = assert(header:byte(5)) * 256 + assert(header:byte(6))
	local version_complement = assert(header:byte(7)) * 256 + assert(header:byte(8))
	assert(version + version_complement == 0xffff, "bad IFS version complement")
	local data_offset = assert(header:byte(17)) * 0x1000000
		+ assert(header:byte(18)) * 0x10000
		+ assert(header:byte(19)) * 0x100
		+ assert(header:byte(20))
	local manifest_start = version > 1 and 36 or 20
	assert(data_offset >= manifest_start, "invalid IFS data offset")
	local manifest, manifest_err = fs:readAt(
		archive_path,
		manifest_start,
		data_offset - manifest_start
	)
	assert(manifest, manifest_err)
	local parsed = Ifs.parse_manifest(header, manifest)
	parsed.read_at = function(offset, size)
		return fs:readAt(archive_path, offset, size)
	end
	return parsed
end

---@param fs fs.IFilesystem
---@param archive_path string
---@return chart.iidx.IfsArchive?
---@return string?
function ChartfileReader.readArchive(fs, archive_path)
	local header, err = fs:readAt(archive_path, 0, 37)
	if not header then
		return nil, err
	end

	local ok, archive = pcall(parseArchive, fs, archive_path, header)
	if not ok then
		local message = ("failed to read IFS archive %s: %s"):format(archive_path, tostring(archive))
		print(message)
		return nil, message
	end
	---@cast archive chart.iidx.IfsArchive
	return archive
end

---@param fs fs.IFilesystem
---@param archive_path string
---@return string[]?
---@return string?
function ChartfileReader.listArchive(fs, archive_path)
	local archive, err = ChartfileReader.readArchive(fs, archive_path)
	if not archive then
		return nil, err
	end
	local paths = {}
	for _, file in ipairs(Ifs.list(archive)) do
		paths[#paths + 1] = file.path
	end
	table.sort(paths)
	return paths
end

---@param fs fs.IFilesystem
---@param path string
---@return string? data
---@return string? err
function ChartfileReader.read(fs, path)
	local archive_path, chart_path = ChartfileReader.splitArchivePath(path)
	if not archive_path then
		return fs:read(path)
	end

	local archive, err = ChartfileReader.readArchive(fs, archive_path)
	if not archive then
		return nil, err
	end

	local chart_data = Ifs.read_file(archive, assert(chart_path))
	if not chart_data then
		return nil, "file not found in chart archive"
	end

	return chart_data
end

---@param fs fs.IFilesystem
---@param path string
---@return fs.FileInfo?
function ChartfileReader.getInfo(fs, path)
	local archive_path = ChartfileReader.splitArchivePath(path)
	if not archive_path then
		return fs:getInfo(path)
	end

	local archive_info = fs:getInfo(archive_path)
	if not archive_info then
		return nil
	end

	local archive = ChartfileReader.readArchive(fs, archive_path)
	if not archive then
		return nil
	end
	local _, internal_path = ChartfileReader.splitArchivePath(path)
	for _, file in ipairs(Ifs.list(archive)) do
		if file.path == internal_path then
			return {
				type = "file",
				size = file.size,
				modtime = archive_info.modtime,
			}
		end
	end
	return nil
end

return ChartfileReader
