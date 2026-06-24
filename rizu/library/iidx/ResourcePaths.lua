local path_util = require("path_util")

---@class rizu.library.iidx.ResourcePaths
local ResourcePaths = {}

---@param chartview table
---@param fs fs.IFilesystem?
---@return string?
function ResourcePaths.getMoviePath(chartview, fs)
	if not fs or chartview.format ~= "iidx" or not chartview.location_prefix then
		return nil
	end

	local movie_path = path_util.join(chartview.location_prefix, "movie")
	if fs:getInfo(movie_path) then
		return movie_path
	end
end

return ResourcePaths
