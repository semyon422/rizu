local class = require("class")
local path_util = require("path_util")

---@class rizu.select.services.ChartMediaService
---@operator call: rizu.select.services.ChartMediaService
local ChartMediaService = class()

-- shortcut: a chart of a remote location keeps the catalog's media after its files are downloaded,
-- use the local files once it matters (notes and video previews are only made from those)

---@param chartview rizu.library.LocatedChartview
---@param remote_assets rizu.library.RemoteAssets? Of a chart of a remote location.
---@return string? path A path, or an url.
function ChartMediaService:getBackgroundPath(chartview, remote_assets)
	if remote_assets then
		return remote_assets.background_url
	end

	local name = chartview.chartfile_name
	if name:find("%.ojn$") or name:find("%.mid$") then
		return chartview.location_path
	end

	local background_path = chartview.background_path
	if not background_path or background_path == "" then
		return chartview.location_dir
	end

	return path_util.join(chartview.location_dir, background_path)
end

---@param chartview rizu.library.LocatedChartview
---@param remote_assets rizu.library.RemoteAssets? Of a chart of a remote location.
---@return string? full_path A path, or the url of an audio preview that is played from its start.
---@return number? preview_time
---@return string? mode
function ChartMediaService:getAudioPathPreview(chartview, remote_assets)
	if remote_assets then
		return remote_assets.audio_preview_url, 0, "absolute"
	end

	local mode = "absolute"

	local audio_path = chartview.audio_path
	if not audio_path or audio_path == "" then
		return "", 0.4, "relative"
	end

	local full_path = path_util.join(chartview.real_dir, audio_path)
	local preview_time = chartview.preview_time

	local format = chartview.format
	if preview_time < 0 and (format == "osu" or format == "qua") then
		mode = "relative"
		preview_time = 0.4
	end

	return full_path, preview_time, mode
end

return ChartMediaService
