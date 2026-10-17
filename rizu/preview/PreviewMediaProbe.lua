local class = require("class")
local ChartfileReader = require("rizu.library.ChartfileReader")
local IidxResourcePaths = require("rizu.library.iidx.ResourcePaths")

---@class rizu.preview.PreviewMediaInfo
---@field audio_exists boolean
---@field bga_exists boolean
---@field bga_paths string[]

---@class rizu.preview.PreviewMediaProbe
---@operator call: rizu.preview.PreviewMediaProbe
local PreviewMediaProbe = class()

---@param fs fs.IFilesystem
function PreviewMediaProbe:new(fs)
	self.fs = fs
end

---@param chartview rizu.preview.PreviewChartview
---@return rizu.preview.PreviewMediaInfo
function PreviewMediaProbe:probe(chartview)
	local fs = self.fs
	local hash = chartview.hash
	local paths = {}
	local archive = chartview.location_path and ChartfileReader.splitArchivePath(chartview.location_path)
	local directory = archive or chartview.location_dir
	if directory then paths[#paths + 1] = directory end
	local movie = IidxResourcePaths.getMoviePath(chartview, fs)
	if movie then paths[#paths + 1] = movie end
	return {
		audio_exists = fs:getInfo("userdata/audio_previews/" .. hash .. ".audio_preview") ~= nil,
		bga_exists = fs:getInfo("userdata/bga_previews/" .. hash .. ".bga_preview") ~= nil,
		bga_paths = paths,
	}
end

return PreviewMediaProbe
