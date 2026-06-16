local PreviewModel = require("rizu.preview.PreviewModel")

local test = {}

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
	previewModel.bgaPreviewPlayer = {
		stopCount = 0,
		stop = function(self)
			self.stopCount = self.stopCount + 1
		end,
	}
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

	previewModel:load()
	previewModel:stop()
	previewModel:setAudioPathPreview("song.ogg", 12, "absolute", {hash = "hash"})
	previewModel:update()

	t:eq(previewModel.active, false)
	t:eq(previewModel.audio_path, nil)
	t:eq(previewModel.chartview, nil)
	t:eq(previewModel.audioPreviewPlayer.stopCount, 1)
	t:eq(previewModel.bgaPreviewPlayer.stopCount, 1)
	t:eq(previewModel.audioPreviewPlayer.pauseCount, 1)
	t:eq(previewModel.chartPreview.chartview, nil)

	previewModel:load()
	previewModel:setAudioPathPreview("song.ogg", 12, "absolute", {hash = "hash"})

	t:eq(previewModel.active, true)
	t:eq(previewModel.audio_path, "song.ogg")
end

return test
