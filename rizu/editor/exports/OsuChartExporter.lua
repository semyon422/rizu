local class = require("class")
local OsuChartEncoder = require("chart.format.osu.ChartEncoder")

---@class rizu.editor.exports.OsuChartExporterDeps
---@field chartEncoder chart.osu.ChartEncoder?

---@class rizu.editor.exports.OsuChartExporter
---@operator call: rizu.editor.exports.OsuChartExporter
---@field fs fs.IFilesystem
local OsuChartExporter = class()

---@param fs fs.IFilesystem
---@param deps rizu.editor.exports.OsuChartExporterDeps?
function OsuChartExporter:new(fs, deps)
	deps = deps or {}
	self.fs = fs
	self.chartEncoder = deps.chartEncoder or OsuChartEncoder()
end

---@param editorModel rizu.editor.EditorModel
---@return string
function OsuChartExporter:encode(editorModel)
	return self.chartEncoder:encode({{
		chart = editorModel.chart,
		chartmeta = editorModel.chartmeta,
	}})
end

---@param chartview table
---@param editorModel rizu.editor.EditorModel
function OsuChartExporter:export(chartview, editorModel)
	editorModel:save()

	local path = chartview.location_path:gsub(".osu$", ""):gsub(".sph$", "") .. ".sph.osu"
	assert(self.fs:write(path, self:encode(editorModel)))
end

return OsuChartExporter
