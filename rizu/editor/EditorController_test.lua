local EditorController = require("rizu.editor.EditorController")
local EditorDropImport = require("rizu.editor.controller.EditorDropImport")
local FakeFilesystem = require("fs.FakeFilesystem")

local test = {}

---@param fields table
---@return rizu.editor.EditorController
local function createController(fields)
	return EditorController(fields)
end

local function createEditorModel(calls, onLoadResources)
	return {
		setNoteSkin = function(self, noteSkin)
			self.noteSkin = noteSkin
		end,
		getNoteSkin = function(self)
			return self.noteSkin
		end,
		load = function(self)
			table.insert(calls, "editor-load")
			if self.onLoad then
				self:onLoad()
			end
		end,
		loadResources = onLoadResources or function(_, resources)
			table.insert(calls, "editor-resources:" .. resources.loaded)
		end,
	}
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
	local editorModel = createEditorModel(calls)
	function editorModel:onLoad()
		t:eq(self.chart, chart)
		t:eq(self.chartmeta, chartmeta)
		t:eq(self:getNoteSkin(), noteSkin)
	end

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
function test.load_resource_failure_propagates_before_vsync_switch(t)
	local calls = {}
	local chart = {
		inputMode = "4key",
		resources = {
			audio = "song.ogg",
		},
	}
	local controller = createController({
		chartSelector = {
			chartview = {
				location_dir = "chart/path",
			},
			loadChart = function()
				table.insert(calls, "chart-load")
				return chart, {}
			end,
		},
		editorModel = createEditorModel(calls, function()
			table.insert(calls, "editor-resources")
			error("resource load failed")
		end),
		noteSkinModel = {
			loadNoteSkin = function()
				return {
					directoryPath = "skin/path",
					loadData = function()
						table.insert(calls, "skin-load")
					end,
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
				table.insert(calls, "resource-model")
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
			addPath = function() end,
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
			addPath = function() end,
		},
		resource_loader = {
			resources = {},
			load = function()
				table.insert(calls, "resource-loader")
			end,
		},
		isModifierApplyRequested = function()
			return false
		end,
	})

	t:has_error(function()
		controller:load()
	end)

	t:tdeq(calls, {
		"chart-load",
		"skin-load",
		"editor-load",
		"preview-stop",
		"file-reset",
		"resource-reset",
		"resource-loader",
		"resource-model",
		"editor-resources",
	})
end

---@param t testing.T
function test.load_applies_modifiers_when_requested(t)
	local appliedModifiers
	local appliedChart

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
		editorModel = createEditorModel({}, function() end),
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
		modifierModel = {
			apply = function(_, modifiers, loadedChart)
				appliedModifiers = modifiers
				appliedChart = loadedChart
			end,
		},
	})

	controller:load()

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
function test.save_delegates_to_sph_saver(t)
	local chartview = {
		location_path = "charts/example.osu",
		dir = "charts",
		location_id = 42,
	}
	local editorModel = {
		id = "editor",
	}
	local library = {
		id = "library",
	}
	local savedChartview
	local savedEditorModel
	local savedLibrary
	local controller = createController({
		chartSelector = {
			chartview = chartview,
		},
		editorModel = editorModel,
		library = library,
		sphChartSaver = {
			save = function(_, cv, model, lib)
				savedChartview = cv
				savedEditorModel = model
				savedLibrary = lib
			end,
		},
	})

	controller:save()

	t:eq(savedChartview, chartview)
	t:eq(savedEditorModel, editorModel)
	t:eq(savedLibrary, library)
end

---@param t testing.T
function test.save_to_osu_delegates_to_exporter(t)
	local chartview = {
		location_path = "charts/example.sph",
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
		osuChartExporter = {
			export = function(_, cv, model)
				exportedChartview = cv
				exportedEditorModel = model
			end,
		},
	})

	controller:saveToOsu()

	t:eq(exportedChartview, chartview)
	t:eq(exportedEditorModel, editorModel)
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
