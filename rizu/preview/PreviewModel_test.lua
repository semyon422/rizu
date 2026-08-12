local PreviewModel = require("rizu.preview.PreviewModel")

local test = {}

---@class rizu.preview.FakeAudioPreviewPlayer
---@field pauseCount integer
---@field stopCount integer
---@field pause fun(self: rizu.preview.FakeAudioPreviewPlayer)
---@field stop fun(self: rizu.preview.FakeAudioPreviewPlayer)

---@class rizu.preview.FakeBgaPreviewPlayer
---@field stopCount integer
---@field stop fun(self: rizu.preview.FakeBgaPreviewPlayer)

---@class rizu.preview.FakeChartPreview
---@field chartview string|rizu.preview.PreviewChartview?
---@field setChartview fun(self: rizu.preview.FakeChartPreview, chartview: rizu.preview.PreviewChartview?)

local function createConfigModel()
	return {
		configs = {
			settings = {
				audio = {
					mode = {
						primary = "",
					},
					volume = {
						master = 1,
						music = 1,
					},
				},
				gameplay = {
					scaleSpeed = true,
					speed = 1,
				},
				miscellaneous = {
					muteOnUnfocus = false,
				},
				select = {
					chart_preview = true,
				},
			},
		},
	}
end

---@return rizu.preview.PreviewModel
local function createPreviewModel()
	local previewModel = PreviewModel(createConfigModel(), {}, {})
	---@type rizu.preview.FakeAudioPreviewPlayer
	previewModel.audioPreviewPlayer = {
		pauseCount = 0,
		stopCount = 0,
		pause = function(self)
			self.pauseCount = self.pauseCount + 1
		end,
		stop = function(self)
			self.stopCount = self.stopCount + 1
		end,
	}
	---@type rizu.preview.FakeBgaPreviewPlayer
	previewModel.bgaPreviewPlayer = {
		stopCount = 0,
		stop = function(self)
			self.stopCount = self.stopCount + 1
		end,
	}
	---@type rizu.preview.FakeChartPreview
	previewModel.chartPreview = {
		chartview = "existing",
		setChartview = function(self, chartview)
			self.chartview = chartview
		end,
	}
	return previewModel
end

---@param t testing.T
function test.stop_disables_preview_until_loaded_again(t)
	local previewModel = createPreviewModel()

	local chartview = {
		hash = "hash",
		location_path = "song.sph",
		location_prefix = "",
		location_dir = "",
		chartfile_name = "song.sph",
		index = 1,
	}
	previewModel:load()
	previewModel:stop()
	previewModel:setAudioPathPreview("song.ogg", 12, "absolute", chartview)
	previewModel:update()

	t:eq(previewModel.active, false)
	t:eq(previewModel.audio_path, nil)
	t:eq(previewModel.chartview, nil)
	t:eq(previewModel.audioPreviewPlayer.stopCount, 1)
	t:eq(previewModel.bgaPreviewPlayer.stopCount, 1)
	t:eq(previewModel.audioPreviewPlayer.pauseCount, 1)
	t:eq(previewModel.chartPreview.chartview, nil)

	previewModel:load()
	previewModel:setAudioPathPreview("song.ogg", 12, "absolute", chartview)

	t:eq(previewModel.active, true)
	t:eq(previewModel.audio_path, "song.ogg")
end

return test
