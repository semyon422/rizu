local ChartEncoder = require("chart.format.sph.ChartEncoder")
local EditorController = require("rizu.editor.EditorController")
local FakeFilesystem = require("fs.FakeFilesystem")
local OsuChartEncoder = require("chart.format.osu.ChartEncoder")

local test = {}

local function installLoveKeyboardStub()
	local oldLove = love
	love = {
		keyboard = {
			isDown = function()
				return false
			end,
		},
	}
	return function()
		love = oldLove
	end
end

---@param fields table
---@return rizu.editor.EditorController
local function createController(fields)
	return EditorController(
		fields.chartSelector,
		fields.editorModel,
		fields.noteSkinModel,
		fields.configModel,
		fields.resourceModel,
		fields.windowModel,
		fields.library,
		fields.fileFinder,
		fields.previewModel,
		fields.replayBase,
		fields.resource_finder,
		fields.resource_loader,
		fields.fs
	)
end

---@param t testing.T
function test.load_wires_chart_skin_resources_and_window(t)
	local restoreLove = installLoveKeyboardStub()
	local calls = {}
	local chart = {
		inputMode = setmetatable({}, {
			__tostring = function()
				return "4key"
			end,
		}),
		resources = {
			audio = "song.ogg",
		},
	}
	local chartmeta = {
		title = "Title",
	}
	local noteSkin = {
		directoryPath = "skin/path",
		loadData = function(self)
			table.insert(calls, "skin-load")
		end,
	}
	local fileFinderPaths = {}
	local resourceFinderPaths = {}
	local editorModel = {
		session = {},
		load = function(self)
			table.insert(calls, "editor-load")
			t:eq(self.chart, chart)
			t:eq(self.chartmeta, chartmeta)
			t:eq(self.session.noteSkin, noteSkin)
		end,
		loadResources = function(_, resources)
			table.insert(calls, "editor-resources:" .. resources.loaded)
		end,
	}

	local controller = createController({
		chartSelector = {
			chartview = {
				location_dir = "chart/path",
			},
			loadChart = function()
				table.insert(calls, "chart-load")
				return chart, chartmeta
			end,
		},
		editorModel = editorModel,
		noteSkinModel = {
			loadNoteSkin = function(_, inputMode)
				table.insert(calls, "skin:" .. inputMode)
				return noteSkin
			end,
		},
		configModel = {
			configs = {
				settings = {
					gameplay = {
						skin_resources_top_priority = true,
					},
				},
			},
		},
		resourceModel = {
			load = function(_, loadedChart, callback)
				table.insert(calls, "resource-model")
				t:eq(loadedChart, chart)
				callback()
			end,
		},
		windowModel = {
			setVsyncOnSelect = function(_, enabled)
				table.insert(calls, "vsync:" .. tostring(enabled))
			end,
		},
		library = {},
		fileFinder = {
			reset = function()
				table.insert(calls, "file-reset")
			end,
			addPath = function(_, path)
				table.insert(fileFinderPaths, path)
			end,
		},
		previewModel = {
			stop = function()
				table.insert(calls, "preview-stop")
			end,
		},
		replayBase = {
			modifiers = {},
		},
		resource_finder = {
			reset = function()
				table.insert(calls, "resource-reset")
			end,
			addPath = function(_, path)
				table.insert(resourceFinderPaths, path)
			end,
		},
		resource_loader = {
			resources = {
				loaded = "yes",
			},
			load = function(_, resources)
				table.insert(calls, "resource-load:" .. resources.audio)
			end,
		},
	})

	controller:load()
	restoreLove()

	t:eq(noteSkin.editor, true)
	t:tdeq(fileFinderPaths, {"skin/path", "chart/path", "userdata/hitsounds", "userdata/hitsounds/midi"})
	t:tdeq(resourceFinderPaths, fileFinderPaths)
	t:tdeq(calls, {
		"chart-load",
		"skin:4key",
		"skin-load",
		"editor-load",
		"preview-stop",
		"file-reset",
		"resource-reset",
		"resource-load:song.ogg",
		"resource-model",
		"editor-resources:yes",
		"vsync:false",
	})
end

---@param t testing.T
function test.unload_restores_vsync(t)
	local calls = {}
	local controller = createController({
		editorModel = {
			unload = function()
				table.insert(calls, "editor-unload")
			end,
		},
		windowModel = {
			setVsyncOnSelect = function(_, enabled)
				table.insert(calls, "vsync:" .. tostring(enabled))
			end,
		},
	})

	controller:unload()

	t:tdeq(calls, {"editor-unload", "vsync:true"})
end

---@param t testing.T
function test.save_writes_sph_and_recomputes_library(t)
	local oldEncode = ChartEncoder.encode
	local fs = FakeFilesystem()
	fs:createDirectory("charts")
	ChartEncoder.encode = function(_, payload)
		t:eq(payload[1].chart.id, "chart")
		t:eq(payload[1].chartmeta.title, "Title")
		return "encoded"
	end

	local calls = {}
	local controller = createController({
		chartSelector = {
			chartview = {
				location_path = "charts/example.osu",
				dir = "charts",
				location_id = 42,
			},
		},
		editorModel = {
			chart = {
				id = "chart",
			},
			chartmeta = {
				title = "Title",
			},
			save = function()
				table.insert(calls, "save")
			end,
			genGraphs = function()
				table.insert(calls, "graphs")
			end,
		},
		library = {
			computeLocation = function(_, dir, locationId)
				table.insert(calls, ("library:%s:%s"):format(dir, locationId))
			end,
		},
		fs = fs,
	})

	controller:save()
	ChartEncoder.encode = oldEncode

	t:tdeq(calls, {"save", "graphs", "library:charts:42"})
	t:eq(fs:read("charts/example.osu.sph"), "encoded")
end

---@param t testing.T
function test.save_to_osu_writes_sph_osu(t)
	local oldEncode = OsuChartEncoder.encode
	local fs = FakeFilesystem()
	fs:createDirectory("charts")
	OsuChartEncoder.encode = function(_, payload)
		t:eq(payload[1].chart.id, "chart")
		t:eq(payload[1].chartmeta.title, "Title")
		return "osu-encoded"
	end

	local calls = {}
	local controller = createController({
		chartSelector = {
			chartview = {
				location_path = "charts/example.sph",
			},
		},
		editorModel = {
			chart = {
				id = "chart",
			},
			chartmeta = {
				title = "Title",
			},
			save = function()
				table.insert(calls, "save")
			end,
		},
		fs = fs,
	})

	controller:saveToOsu()
	OsuChartEncoder.encode = oldEncode

	t:tdeq(calls, {"save"})
	t:eq(fs:read("charts/example.sph.osu"), "osu-encoded")
end

---@param t testing.T
function test.filedropped_writes_audio_through_filesystem(t)
	local fs = FakeFilesystem()
	fs:createDirectory("userdata")
	fs:createDirectory("userdata/charts")
	fs:createDirectory("userdata/charts/editor")
	local oldTime = os.time
	os.time = function()
		return 123
	end

	local controller = createController({
		fs = fs,
	})
	controller:filedropped({
		getFilename = function()
			return "drop/song.ogg"
		end,
		read = function()
			return "audio-data"
		end,
	})
	os.time = oldTime

	t:eq(fs:read("userdata/charts/editor/123 song/song.ogg"), "audio-data")
end

return test
