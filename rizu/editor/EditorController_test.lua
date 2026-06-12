local ChartEncoder = require("chart.format.sph.ChartEncoder")
local EditorController = require("rizu.editor.EditorController")
local EditorDropImport = require("rizu.editor.EditorDropImport")
local FakeFilesystem = require("fs.FakeFilesystem")
local OsuChartEncoder = require("chart.format.osu.ChartEncoder")
local ModifierModel = require("sphere.models.ModifierModel")

local test = {}

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
		fields.fs,
		fields.isModifierApplyRequested,
		fields.dropImport,
		fields.nanoChartExporter
	)
end

---@param t testing.T
function test.load_wires_chart_skin_resources_and_window(t)
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
		isModifierApplyRequested = function()
			return false
		end,
	})

	controller:load()

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
function test.load_applies_modifiers_when_requested(t)
	local oldApply = ModifierModel.apply
	local appliedModifiers
	local appliedChart
	ModifierModel.apply = function(_, modifiers, chart)
		appliedModifiers = modifiers
		appliedChart = chart
	end

	local chart = {
		inputMode = setmetatable({}, {
			__tostring = function()
				return "4key"
			end,
		}),
		resources = {},
	}
	local modifiers = {
		"mirror",
	}
	local controller = createController({
		chartSelector = {
			chartview = {
				location_dir = "chart/path",
			},
			loadChart = function()
				return chart, {}
			end,
		},
		editorModel = {
			session = {},
			load = function() end,
			loadResources = function() end,
		},
		noteSkinModel = {
			loadNoteSkin = function()
				return {
					directoryPath = "skin/path",
					loadData = function() end,
				}
			end,
		},
		configModel = {
			configs = {
				settings = {
					gameplay = {
						skin_resources_top_priority = false,
					},
				},
			},
		},
		resourceModel = {
			load = function(_, _, callback)
				callback()
			end,
		},
		windowModel = {
			setVsyncOnSelect = function() end,
		},
		library = {},
		fileFinder = {
			reset = function() end,
			addPath = function() end,
		},
		previewModel = {
			stop = function() end,
		},
		replayBase = {
			modifiers = modifiers,
		},
		resource_finder = {
			reset = function() end,
			addPath = function() end,
		},
		resource_loader = {
			resources = {},
			load = function() end,
		},
		isModifierApplyRequested = function()
			return true
		end,
	})

	controller:load()
	ModifierModel.apply = oldApply

	t:eq(appliedModifiers, modifiers)
	t:eq(appliedChart, chart)
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
function test.save_errors_when_sph_write_fails(t)
	local oldEncode = ChartEncoder.encode
	ChartEncoder.encode = function()
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
			chart = {},
			chartmeta = {},
			save = function()
				table.insert(calls, "save")
			end,
			genGraphs = function()
				table.insert(calls, "graphs")
			end,
		},
		library = {
			computeLocation = function()
				table.insert(calls, "library")
			end,
		},
		fs = {
			write = function()
				return false
			end,
		},
	})

	t:has_error(function()
		controller:save()
	end)
	ChartEncoder.encode = oldEncode

	t:tdeq(calls, {"save", "graphs"})
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
function test.save_to_osu_errors_when_write_fails(t)
	local oldEncode = OsuChartEncoder.encode
	OsuChartEncoder.encode = function()
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
			chart = {},
			chartmeta = {},
			save = function()
				table.insert(calls, "save")
			end,
		},
		fs = {
			write = function()
				return false
			end,
		},
	})

	t:has_error(function()
		controller:saveToOsu()
	end)
	OsuChartEncoder.encode = oldEncode

	t:tdeq(calls, {"save"})
end

---@param t testing.T
function test.save_to_nanochart_delegates_to_exporter(t)
	local chartview = {
		real_path = "charts/example",
	}
	local editorModel = {
		id = "editor",
	}
	local exportedChartview
	local exportedEditorModel
	local controller = createController({
		chartSelector = {
			chartview = chartview,
		},
		editorModel = editorModel,
		nanoChartExporter = {
			export = function(_, cv, model)
				exportedChartview = cv
				exportedEditorModel = model
			end,
		},
	})

	controller:saveToNanoChart()

	t:eq(exportedChartview, chartview)
	t:eq(exportedEditorModel, editorModel)
end

---@param t testing.T
function test.filedropped_delegates_to_drop_import(t)
	local fs = FakeFilesystem()
	local controller = createController({
		fs = fs,
		dropImport = EditorDropImport(fs, function()
			return 123
		end),
	})
	controller:filedropped({
		getFilename = function()
			return "drop/song.ogg"
		end,
		read = function()
			return "audio-data"
		end,
	})

	t:eq(fs:read("userdata/charts/editor/123 song/song.ogg"), "audio-data")
end

return test
