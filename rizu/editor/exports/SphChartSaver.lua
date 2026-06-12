local class = require("class")
local ChartEncoder = require("chart.format.sph.ChartEncoder")

---@class rizu.editor.exports.SphChartSaverDeps
---@field chartEncoder chart.sph.ChartEncoder?

---@class rizu.editor.exports.SphChartSaver
---@operator call: rizu.editor.exports.SphChartSaver
---@field fs fs.IFilesystem
local SphChartSaver = class()

---@param fs fs.IFilesystem
---@param deps rizu.editor.exports.SphChartSaverDeps?
function SphChartSaver:new(fs, deps)
	deps = deps or {}
	self.fs = fs
	self.chartEncoder = deps.chartEncoder or ChartEncoder()
end

---@param editorModel rizu.editor.EditorModel
---@return string
function SphChartSaver:encode(editorModel)
	return self.chartEncoder:encode({{
		chart = editorModel.chart,
		chartmeta = editorModel.chartmeta,
	}})
end

---@param chartview table
---@param editorModel rizu.editor.EditorModel
---@param library rizu.library
function SphChartSaver:save(chartview, editorModel, library)
	editorModel:save()
	editorModel:genGraphs()

	local path = chartview.location_path:gsub(".sph$", "") .. ".sph"
	assert(self.fs:write(path, self:encode(editorModel)))

	library:computeLocation(chartview.dir, chartview.location_id)
end

return SphChartSaver
