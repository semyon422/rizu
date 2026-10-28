local PreviewLoader = require("rizu.preview.PreviewLoader")
local PreviewModel = require("rizu.preview.PreviewModel")
local FakeFilesystem = require("fs.FakeFilesystem")
local Settings = require("rizu.config.Settings")
local TwoDx = require("chart.format.iidx.TwoDx")
local NotesPreviewPlayer = require("rizu.preview.NotesPreviewPlayer")
local SphPreview = require("chart.format.sph.SphPreview")
local Fraction = require("chart.core.Fraction")

local test = {}

---@class rizu.preview.FakeAudioPreviewPlayer
---@field pauseCount integer
---@field stopCount integer
---@field pause fun(self: rizu.preview.FakeAudioPreviewPlayer)
---@field stop fun(self: rizu.preview.FakeAudioPreviewPlayer)
---@field getRange fun(self: rizu.preview.FakeAudioPreviewPlayer): number, number
---@field getPosition fun(self: rizu.preview.FakeAudioPreviewPlayer): number
---@field resume fun(self: rizu.preview.FakeAudioPreviewPlayer)
---@field update fun(self: rizu.preview.FakeAudioPreviewPlayer)

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
		getRange = function() return 0, 0 end,
		getPosition = function() return 0 end,
		resume = function() end,
		update = function() end,
	}
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
	local async = get_upvalue(PreviewLoader.startPreviewGeneration, "generatePreviewAsync")
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

---@param t testing.T
function test.broken_notes_preview_requests_repair(t)
	local settings = Settings.createConfig(FakeFilesystem())
	local player = NotesPreviewPlayer(settings, {}, {}, {})
	local preview = SphPreview:encode({
		{offset = 0.724609375, notes = {true}},
		{time = Fraction(1, 4), notes = {true}},
	}, 1)
	t:eq(player:setChartview({notes_preview = preview, chartdiff_inputmode = "7key"}), false)
	t:eq(player.chart, nil)
	t:eq(player:setChartview(nil), nil)
end

---@param t testing.T
function test.worker_returns_repaired_notes(t)
	local async = get_upvalue(PreviewLoader.startPreviewGeneration, "generatePreviewAsync")
	local worker = assert(loadstring(string.dump(get_upvalue(async, "f"))))
	local fake_chart = {layers = {main = {toAbsolute = function() end}}}
	local modules = {
		["bass"] = {initNoSound = function() return true end},
		["fs.LoveFilesystem"] = function()
			return {getInfo = function() return {} end}
		end,
		["rizu.preview.AudioPreviewGenerator"] = function() return {} end,
		["rizu.preview.BgaPreviewGenerator"] = function() return {} end,
		["rizu.library.ChartfileReader"] = {read = function() return "content" end},
		["chart.format.notechart.ChartFactory"] = {
			getCharts = function() return {{chart = fake_chart}} end,
		},
		["chart.format.sph.Sph"] = function()
			return {metadata = {set = function() end}, sphLines = {decode = function() end}}
		end,
		["chart.format.sph.SphPreview"] = {decodeLines = function() return {} end},
		["chart.format.sph.ChartDecoder"] = function()
			return {decodeSph = function() end}
		end,
		["chart.difficulty.PreviewDiffcalc"] = function()
			return {compute = function(_, ctx)
				t:eq(ctx.chart, fake_chart)
				ctx.chartdiff.notes_preview = "repaired"
			end}
		end,
	}
	setfenv(worker, setmetatable({
		print = function() end,
		require = function(name) return modules[name] or {} end,
	}, {__index = _G}))
	local ok, preview = worker({hash = "hash", index = 1, regenerate_notes = true})
	t:eq(ok, true)
	t:eq(preview, "repaired")
	local unchanged, no_preview = worker({hash = "hash", index = 1})
	t:eq(unchanged, true)
	t:eq(no_preview, nil)
end

---@param t testing.T
function test.stale_media_probe_does_not_activate(t)
	local model = createPreviewModel()
	model:load()
	model.chartview = {hash = "old"}
	model.loader.probe_media = function()
		coroutine.yield()
		return {audio_exists = true, bga_exists = true, bga_paths = {}}
	end
	local co = coroutine.create(function() model.loader:loadPreview() end)
	t:assert(coroutine.resume(co))
	model:stop()
	model:load()
	t:assert(coroutine.resume(co))
	t:eq(coroutine.status(co), "dead")
	t:eq(model.loaded_audio_hash, nil)
	t:eq(model.loaded_hash, nil)
end

---@param t testing.T
function test.selection_blanks_notes_before_skin_binding(t)
	local model = createPreviewModel()
	model:load()
	model.skinCache.bind = function()
		t:eq(model.chartPreview.chartview, nil)
		t:eq(model:getMediaState(), "loading")
	end
	model:setAudioPathPreview("song.ogg", 12, "absolute", {hash = "a"})
	t:eq(model.chartPreview.chartview, nil)
	model:stop()
end

---@param t testing.T
function test.final_release_releases_cache_loader_and_players_once(t)
	local model = createPreviewModel()
	local counts = {audio = 0, bga = 0}
	model.audioPreviewPlayer.release = function() counts.audio = counts.audio + 1 end
	model.bgaPreviewPlayer.release = function() counts.bga = counts.bga + 1 end
	model:load()
	model:release()
	model:release()
	t:eq(counts.audio, 1)
	t:eq(counts.bga, 1)
	t:eq(model.active, false)
	t:eq(model.loader.released, true)
	t:eq(model.skinCache.released, true)
	t:eq(model.skinCache.unsubscribe, nil)
end

---@param t testing.T
function test.shared_audio_keeps_decoder_and_position_but_changes_bga(t)
	local model = createPreviewModel()
	local loads = {audio = 0, bga = 0}
	model.audioPreviewPlayer.load = function() loads.audio = loads.audio + 1 end
	model.audioPreviewPlayer.setVolume = function() end
	model.audioPreviewPlayer.setRate = function() end
	model.audioPreviewPlayer.seek = function() end
	model.bgaPreviewPlayer.load = function() loads.bga = loads.bga + 1 end
	model.bgaPreviewPlayer.seek = function() end
	model:load()
	model.audio_path = "shared.ogg"
	local media = {audio_exists = true, bga_exists = true, bga_paths = {}}
	local a = {hash = "a", location_path = "a.sph", location_dir = ""}
	local b = {hash = "b", location_path = "b.sph", location_dir = ""}
	model.chartview = a
	model:applyPreparedMedia(media, "shared.ogg", 12, "absolute", a)
	model.manual_time = 20
	model.chartview = b
	model:applyPreparedMedia(media, "shared.ogg", 30, "absolute", b)
	t:eq(loads.audio, 1)
	t:eq(loads.bga, 2)
	t:eq(model.manual_time, 20)
end

---@param t testing.T
function test.selection_changed_by_stop_observer_cannot_load_captured_media(t)
	local model = createPreviewModel()
	model:load()
	local cv = {hash = "a", location_path = "a.sph", location_dir = ""}
	model.audio_path = "a.ogg"
	model.chartview = cv
	local loads = 0
	model.audioPreviewPlayer.load = function() loads = loads + 1 end
	model.audioPreviewPlayer.stop = function()
		model.audio_path = "b.ogg"
		model.chartview = {hash = "b"}
	end
	model:applyPreparedMedia({audio_exists = true, bga_exists = true, bga_paths = {}}, "a.ogg", 0, "absolute", cv)
	t:eq(loads, 0)
	t:eq(model.loaded_audio_path, nil)
end

---@param t testing.T
function test.no_selection_keeps_preview_active_for_the_next_chart(t)
	local model = createPreviewModel()
	model:load()
	model:setAudioPathPreview(nil, nil, nil, nil)
	t:eq(model.loader:loadPreview(), "empty")
	t:eq(model.active, true)
	model:setAudioPathPreview("song.ogg", 12, "absolute", {hash = "a"} --[[@as rizu.preview.PreviewChartview]])
	t:eq(model.audio_path, "song.ogg")
	model:stop()
end

---@param model rizu.preview.PreviewModel
---@param min_time number
---@param max_time number
---@return {seeks: number[], position: number}
local function playAudio(model, min_time, max_time)
	---@type {seeks: number[], position: number}
	local audio = {seeks = {}, position = 5}
	local player = model.audioPreviewPlayer --[[@as table]]
	player.getRange = function() return min_time, max_time end
	player.getPosition = function() return audio.position end
	---@param time number
	player.seek = function(_, time)
		audio.seeks[#audio.seeks + 1] = time
		audio.position = time
	end
	model.bgaPreviewPlayer.seek = function() end
	model.bgaPreviewPlayer.update = function() end
	model.chartPreview.update = function() end
	model.skinCache.update = function() end
	model.audioPreviewPlayer.setVolume = function() end
	model.audioPreviewPlayer.setRate = function() end
	return audio
end

---@param t testing.T
function test.start_mode_picks_the_first_position(t)
	local model = createPreviewModel()
	model:load()
	model.preview_time = 5
	local audio = playAudio(model, 1, 11)
	model:update()
	t:tdeq(audio.seeks, {})

	model.initial_seek_done = false
	model.settings:setBoolean(Settings.keys.select.random_preview_position, true)
	model:update()
	t:assert(audio.position >= 3 and audio.position <= 9)

	model.initial_seek_done = false
	model:setModes("start", "loop")
	model:update()
	t:eq(audio.position, 1)
	model:stop()
end

---@param t testing.T
function test.end_action_selects_a_random_chart_and_waits_for_it(t)
	local model = createPreviewModel()
	local moves = {true, false, false}
	local scrolls = 0
	---@type table
	local chartSelector = {scrollRandom = function()
		scrolls = scrolls + 1
		return moves[scrolls]
	end}
	model.game.chartSelector = chartSelector
	model:load()
	model.initial_seek_done = true
	local audio = playAudio(model, 0, 10)
	local playing = false
	model.audioPreviewPlayer.pause = function() playing = false end
	model.audioPreviewPlayer.resume = function() playing = true end

	model:update()
	audio.position = 10
	model:update()
	t:eq(audio.position, 0)

	model:setModes("start", "random_chart")
	audio.position = 10
	model:update()
	model:update()
	t:eq(scrolls, 1)
	t:eq(model.waiting_next, true)
	t:eq(playing, false)

	-- The new chart has no audio: the next random jumps land on the same set, so it loops.
	model.loader.media_state = "failed"
	model:update()
	t:eq(scrolls, 2)
	t:eq(model.waiting_next, false)
	model:update()
	t:eq(audio.position, 0)
	t:eq(playing, true)
	t:eq(scrolls, 3)
	model:stop()
end

return test
