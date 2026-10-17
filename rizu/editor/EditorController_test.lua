local EditorController = require("rizu.editor.EditorController")
local EditorDropImport = require("rizu.editor.controller.EditorDropImport")
local FakeFilesystem = require("fs.FakeFilesystem")
local Settings = require("rizu.config.Settings")

local test = {}

---@param fields table
---@return rizu.editor.EditorController
local function createController(fields)
	fields.settings = Settings.createConfig(FakeFilesystem())
	return EditorController(fields)
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
	---@type {location_path: string, dir: string, location_id: integer}
	local savedChartview
	---@type {id: string}
	local savedEditorModel
	---@type {id: string}
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
	---@type {location_path: string}
	local exportedChartview
	---@type {id: string}
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
	---@type {real_path: string}
	local exportedChartview
	---@type {id: string}
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
