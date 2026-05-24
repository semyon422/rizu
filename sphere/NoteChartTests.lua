local NoteChartExporter = require("chart.format.osu.NoteChartExporter")
local NoteChartFactory = require("chart.format.notechart.NoteChartFactory")

---@param path string
---@param index number?
---@return ncdk.NoteChart
local function loadNoteChart(path, index)
	return assert(NoteChartFactory:getNoteChart(
		path,
		love.filesystem.read(path),
		index or 1
	))
end

---@param noteChart ncdk.NoteChart
---@return string
local function export(noteChart)
	local nce = NoteChartExporter()
	nce.noteChart = noteChart
	nce.chartmeta = noteChart.chartmeta

	return nce:export()
end

local path = "userdata/testcharts"
return function()
	local files = love.filesystem.getDirectoryItems(path)

	for _, name in ipairs(files) do
		if not name:find("%.out$") then
			local noteChart = loadNoteChart(path .. "/" .. name)

			local out = path .. "/" .. name .. ".out"
			local tested = love.filesystem.read(out)
			local exported = export(noteChart)
			if tested then
				if tested ~= exported then
					love.filesystem.write(path .. "/" .. name .. ".new.out", exported)
					error(name)
				end
			else
				love.filesystem.write(out, exported)
			end
		end
	end
end

