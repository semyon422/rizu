local EditorExportService = require("rizu.editor.controller.EditorExportService")
local FakeFilesystem = require("fs.FakeFilesystem")

local test = {}

---@param calls string[]
---@param name string
---@return table
local function createExportObject(calls, name)
	return {
		slice = function(_, chartSelector, editorModel)
			table.insert(calls, name .. ":slice")
			table.insert(calls, chartSelector.id)
			table.insert(calls, editorModel.id)
		end,
		export = function(_, first, second, third)
			table.insert(calls, name .. ":export")
			table.insert(calls, first.id)
			table.insert(calls, second.id)
			if third then
				table.insert(calls, third[1])
			end
		end,
		save = function(_, chartview, editorModel, library)
			table.insert(calls, name .. ":save")
			table.insert(calls, chartview.id)
			table.insert(calls, editorModel.id)
			table.insert(calls, library.id)
		end,
	}
end

---@param t testing.T
function test.delegates_bms_exports(t)
	local calls = {}
	local service = EditorExportService(FakeFilesystem(), {
		bmsKeysoundSlicer = createExportObject(calls, "keysounds"),
		ubmscExporter = createExportObject(calls, "ubmsc"),
		bmsTemplateExporter = createExportObject(calls, "template"),
	})
	local chartSelector = {
		id = "selector",
	}
	local editorModel = {
		id = "editor",
	}

	service:sliceKeysounds(chartSelector, editorModel)
	service:exportUBmsC(chartSelector, editorModel)
	service:exportBmsTemplate(chartSelector, editorModel, {"1", "2"})

	t:tdeq(calls, {
		"keysounds:slice",
		"selector",
		"editor",
		"ubmsc:export",
		"selector",
		"editor",
		"template:export",
		"selector",
		"editor",
		"1",
	})
end

---@param t testing.T
function test.delegates_chart_saves(t)
	local calls = {}
	local service = EditorExportService(FakeFilesystem(), {
		sphChartSaver = createExportObject(calls, "sph"),
		osuChartExporter = createExportObject(calls, "osu"),
		nanoChartExporter = createExportObject(calls, "nano"),
	})
	local chartview = {
		id = "chartview",
	}
	local editorModel = {
		id = "editor",
	}
	local library = {
		id = "library",
	}

	service:save(chartview, editorModel, library)
	service:saveToOsu(chartview, editorModel)
	service:saveToNanoChart(chartview, editorModel)

	t:tdeq(calls, {
		"sph:save",
		"chartview",
		"editor",
		"library",
		"osu:export",
		"chartview",
		"editor",
		"nano:export",
		"chartview",
		"editor",
	})
end

return test
