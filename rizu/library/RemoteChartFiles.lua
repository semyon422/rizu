local class = require("class")
local digest = require("digest")
local path_util = require("path_util")

---Puts the files of a chart of a remote location on disk, where the files of any other chart are.
---After that the chart is loaded, played and replayed like a local one.
---@class rizu.library.RemoteChartFiles
---@operator call: rizu.library.RemoteChartFiles
---@field library rizu.library.Library
---@field assets rizu.library.RemoteAssetCache
---@field fs fs.IFilesystem
local RemoteChartFiles = class()

---@param library rizu.library.Library
---@param assets rizu.library.RemoteAssetCache
---@param fs fs.IFilesystem
function RemoteChartFiles:new(library, assets, fs)
	self.library = library
	self.assets = assets
	self.fs = fs
end

---The catalog names these files; they must stay inside the location.
---@param path string?
---@return boolean
local function isInside(path)
	return path ~= nil and path ~= "" and not path:find("..", 1, true) and not path:find("^/")
		and not path:find("\\", 1, true)
end

---@private
---@param url string
---@param path string
---@param md5 string? Of the file, when it is known.
---@return true?
---@return string?
function RemoteChartFiles:fetch(url, path, md5)
	if self.fs:getInfo(path) then
		return true
	end
	local body, err = self.assets:download(url)
	if not body then
		return nil, err
	end
	if md5 and digest.hash("md5", body, true) ~= md5 then
		return nil, "the downloaded file is damaged"
	end
	-- shortcut: a write cut short leaves a file that counts as downloaded, check sizes when that is seen
	return self.assets:write(path, body)
end

---Downloads the chart file, its audio and its background unless they are there. Yields.
---Does nothing for a chart of a local location.
---@param chartview rizu.library.LocatedChartview
---@return true?
---@return string?
function RemoteChartFiles:ensure(chartview)
	if not chartview.location_url then
		return true
	end
	local assets = self.library:getRemoteAssets(chartview)
	if not assets then
		return nil, "chart: not in the catalog"
	end
	if not isInside(chartview.path) then
		return nil, "chart: unsupported file name " .. tostring(chartview.path)
	end

	local ok, err = self:fetch(assets.chart_url, chartview.location_path, chartview.hash)
	if not ok then
		return nil, "chart: " .. err
	end

	-- The chart asks for its audio by this name.
	local audio_path = chartview.audio_path
	if not isInside(audio_path) then
		return nil, "audio: unsupported file name " .. tostring(audio_path)
	end
	ok, err = self:fetch(assets.audio_url, path_util.join(chartview.location_dir, audio_path))
	if not ok then
		return nil, "audio: " .. err
	end

	-- A chart without its background is still playable.
	local background_path = chartview.background_path
	if assets.background_url and isInside(background_path) then
		self:fetch(assets.background_url, path_util.join(chartview.location_dir, background_path))
	end
	return true
end

return RemoteChartFiles
