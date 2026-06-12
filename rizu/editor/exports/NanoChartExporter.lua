local class = require("class")
local ChartEncoder = require("chart.format.sph.ChartEncoder")
local NanoChart = require("chart.transform.NanoChart")
local SphPreview = require("chart.format.sph.SphPreview")
local zlib = require("zlib")

---@class rizu.editor.exports.NanoChartExporterDeps
---@field chartEncoder chart.sph.ChartEncoder?
---@field nanoChart chart.NanoChart?
---@field sphPreview chart.sph.SphPreview?
---@field compress (fun(data: string): string)?

---@class rizu.editor.exports.NanoChartExporter
---@operator call: rizu.editor.exports.NanoChartExporter
---@field fs fs.IFilesystem
local NanoChartExporter = class()

---@param fs fs.IFilesystem
---@param deps rizu.editor.exports.NanoChartExporterDeps?
function NanoChartExporter:new(fs, deps)
	deps = deps or {}
	self.fs = fs
	self.chartEncoder = deps.chartEncoder or ChartEncoder()
	self.nanoChart = deps.nanoChart or NanoChart()
	self.sphPreview = deps.sphPreview or SphPreview
	self.compress = deps.compress or zlib.compress
end

---@param chart chart.Chart
---@return table[]
function NanoChartExporter:getNanoNotes(chart)
	local inputMap = chart.inputMode:getInputMap()
	---@type table[]
	local notes = {}

	for _, note in chart.notes:iter() do
		local input = inputMap[note.column]
		local isKey = note.column:match("^key%d+$") ~= nil
		local isStart = note.type == "tap" or note.type == "hold" and note.weight == 1
		if input and isKey and isStart then
			table.insert(notes, {
				time = note.visualPoint.point.absoluteTime,
				type = 1,
				input = input,
			})
		end
	end

	table.sort(notes, function(a, b)
		if a.time ~= b.time then
			return a.time < b.time
		end
		return a.input < b.input
	end)

	return notes
end

---@param path string
---@param data string
function NanoChartExporter:write(path, data)
	assert(self.fs:write(path, data))
end

---@param basePath string
---@param content string
function NanoChartExporter:writeNanoChart(basePath, content)
	self:write(basePath .. ".nanochart_compressed", self.compress(content))
	self:write(basePath .. ".nanochart", content)
end

---@param basePath string
---@param chart chart.Chart
---@param chartmeta sea.Chartmeta?
function NanoChartExporter:writePreviews(basePath, chart, chartmeta)
	local sph = self.chartEncoder:encodeSph(chart, chartmeta)
	local lines = sph.sphLines:encode()

	local content = self.sphPreview:encodeLines(lines)
	self:write(basePath .. ".preview0_compressed", self.compress(content))
	self:write(basePath .. ".preview0", content)

	local content1 = self.sphPreview:encodeLines(lines, 1)
	self:write(basePath .. ".preview1_compressed", self.compress(content1))
	self:write(basePath .. ".preview1", content1)
end

---@param chartview table
---@param editorModel rizu.editor.EditorModel
function NanoChartExporter:export(chartview, editorModel)
	editorModel:save()

	local chart = editorModel.chart
	local emptyHash = string.char(0):rep(16)
	local inputs = chart.inputMode.key or chart.inputMode:getColumns()
	local content = self.nanoChart:encode(emptyHash, inputs, self:getNanoNotes(chart))

	self:writeNanoChart(chartview.real_path, content)
	self:writePreviews(chartview.real_path, chart, editorModel.chartmeta)
end

return NanoChartExporter
