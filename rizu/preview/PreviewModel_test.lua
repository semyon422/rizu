local PreviewModel = require("rizu.preview.PreviewModel")
local FakeFilesystem = require("fs.FakeFilesystem")
local Settings = require("rizu.config.Settings")
local TwoDx = require("chart.format.iidx.TwoDx")

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

---@return rizu.preview.PreviewModel
local function createPreviewModel()
	local settings = Settings.createConfig(FakeFilesystem())
	local previewModel = PreviewModel(settings, {}, {})
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

---@param f function
---@param name string
---@return function
local function get_upvalue(f, name)
	local i = 1
	while true do
		local key, value = debug.getupvalue(f, i)
		assert(key, "missing upvalue: " .. name)
		if key == name then
			return value
		end
		i = i + 1
	end
end

---@param t testing.T
function test.worker_returns_parse_errors_instead_of_throwing(t)
	local async = get_upvalue(PreviewModel.startPreviewGeneration, "generatePreviewAsync")
	local worker = assert(loadstring(string.dump(get_upvalue(async, "f"))))
	setfenv(worker, setmetatable({
		print = function() end,
		require = function()
			TwoDx.parse(string.rep("\0", 76))
		end,
	}, {__index = _G}))

	local ok, result, err = pcall(worker, {hash = "broken-2dx"})
	t:eq(ok, true)
	t:eq(result, false)
	t:eq(type(err), "string")
	t:ne(err:find("unrecognized 2dx header size", 1, true), nil)
end

return test
