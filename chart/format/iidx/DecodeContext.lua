local Catalog = require("chart.format.iidx.Catalog")
local path_util = require("path_util")

---@class chart.iidx.DecodeContextModule
local DecodeContext = {}

---@param chartfile_name string
---@return integer?
local function get_song_id(chartfile_name)
	local song_id = chartfile_name:match("(%d+)")
	return song_id and tonumber(song_id) or nil
end

---@param fs fs.IFilesystem
---@param location_prefix string?
---@param chartfile_name string
---@return chart.iidx.DecodeContext?
function DecodeContext.fromLocation(fs, location_prefix, chartfile_name)
	if not location_prefix then
		return nil
	end
	if not fs:getInfo(path_util.join(location_prefix, "sound")) then
		return nil
	end
	if not fs:getInfo(path_util.join(location_prefix, "info")) then
		return nil
	end
	if not Catalog.isLocation(fs, location_prefix) then
		return nil
	end

	local song_id = get_song_id(chartfile_name)
	if not song_id then
		return nil
	end

	local catalog = Catalog.load(fs, location_prefix)
	local song = catalog and catalog.by_id[song_id]
	if not song then
		return nil
	end

	return {
		song_id = song.song_id,
		iidx_song = song,
	}
end

return DecodeContext
