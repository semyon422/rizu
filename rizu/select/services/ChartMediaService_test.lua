local ChartMediaService = require("rizu.select.services.ChartMediaService")

local test = {}

---@return rizu.library.LocatedChartview
local function createChartview()
	return {
		chartfile_name = "chart.osu",
		location_path = "loc/set/chart.osu",
		location_dir = "loc/set",
		real_dir = "/real/set",
		background_path = "bg.jpg",
		audio_path = "audio.ogg",
		preview_time = 12.5,
		format = "osu",
	}
end

---@param t testing.T
function test.background_path(t)
	local service = ChartMediaService()
	local chartview = createChartview()

	t:eq(service:getBackgroundPath(chartview), "loc/set/bg.jpg")

	chartview.background_path = ""
	t:eq(service:getBackgroundPath(chartview), "loc/set")

	chartview.chartfile_name = "chart.ojn"
	t:eq(service:getBackgroundPath(chartview), "loc/set/chart.osu")
end

---@param t testing.T
function test.audio_path_preview(t)
	local service = ChartMediaService()
	local chartview = createChartview()

	local audio_path, preview_time, mode = service:getAudioPathPreview(chartview)
	t:eq(audio_path, "/real/set/audio.ogg")
	t:eq(preview_time, 12.5)
	t:eq(mode, "absolute")

	chartview.preview_time = -1
	audio_path, preview_time, mode = service:getAudioPathPreview(chartview)
	t:eq(audio_path, "/real/set/audio.ogg")
	t:eq(preview_time, 0.4)
	t:eq(mode, "relative")

	chartview.audio_path = ""
	audio_path, preview_time, mode = service:getAudioPathPreview(chartview)
	t:eq(audio_path, "")
	t:eq(preview_time, 0.4)
	t:eq(mode, "relative")
end

---@param t testing.T
function test.remote_chart_uses_the_media_of_the_catalog(t)
	local service = ChartMediaService()
	local assets = {
		chart_url = "https://cdn.test/c.osu", audio_url = "https://cdn.test/a.webm",
		audio_preview_url = "https://cdn.test/p.webm", background_url = "https://cdn.test/b.avif",
	}
	---@diagnostic disable-next-line: missing-fields
	local chartview = {chartfile_name = "a.osu", location_dir = "online/Song", audio_path = "audio.mp3"}
	t:eq(service:getBackgroundPath(chartview, assets), "https://cdn.test/b.avif")
	t:tdeq({service:getAudioPathPreview(chartview, assets)}, {"https://cdn.test/p.webm", 0, "absolute"})
end

return test
