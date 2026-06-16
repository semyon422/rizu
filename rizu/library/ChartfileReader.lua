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

---@param fs fs.IFilesystem
---@param archive_path string
---@return chart.iidx.IfsArchive?
---@return string?
function ChartfileReader.readArchive(fs, archive_path)
	local archive_data, err = fs:read(archive_path)
	if not archive_data then
		return nil, err
	end
	return Ifs.parse(archive_data)
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

	local data = ChartfileReader.read(fs, path)
	if not data then
		return nil
	end

	return {
		type = "file",
		size = #data,
		modtime = archive_info.modtime,
	}
end

return ChartfileReader
