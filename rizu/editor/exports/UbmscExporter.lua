local class = require("class")
local path_util = require("path_util")
local string_util = require("string_util")
local table_util = require("table_util")
local dpairs = require("dpairs")
local InputMode = require("ncdk.InputMode")

---@class rizu.editor.exports.UbmscExporter
---@operator call: rizu.editor.exports.UbmscExporter
local UbmscExporter = class()

local ubmsc_columns = {
	["10key"] = {6, 7, 8, 9, 10, 14, 15, 16, 17, 18},
}

---@param chartSelector rizu.select.ChartSelector
---@param editorModel rizu.editor.EditorModel
function UbmscExporter:export(chartSelector, editorModel)
	local chartview = chartSelector.chartview
	local real_dir = chartview.real_dir

	local ubmsc_columns_map = ubmsc_columns[chartview.inputmode]
	if not ubmsc_columns_map then
		print(chartview.inputmode .. " not supported")
		return
	end

	local data = love.filesystem.read(path_util.join(real_dir, "iBMSC Clipboard Data xNT.txt"))
	if not data then
		print("'iBMSC Clipboard Data xNT.txt' not found")
		return
	end

	---@type {[integer]: integer[][]}
	local ubmsc_data = {}

	for line in data:gmatch("[^\r\n]+") do
		local tbl = string_util.split(line, " ")
		local time = tonumber(tbl[2])
		if time then
			time = time + 192
			tbl[2] = time
			for i, v in ipairs(tbl) do
				tbl[i] = tonumber(v)
			end
			ubmsc_data[time] = ubmsc_data[time] or {}
			table.insert(ubmsc_data[time], tbl)
		end
	end

	---@type {[integer]: integer[]}
	local pattern_notes = {}

	local columns_map = InputMode(chartview.inputmode):getInputMap()
	for i, linked_note in ipairs(editorModel.notes:getLinkedNotes()) do
		local column = columns_map[linked_note:getColumn()]
		if column then
			local note = linked_note.startNote
			local p = note.visualPoint.point
			---@cast p chartedit.Point

			local time = (p:getGlobalTime() * 48):tonumber()
			pattern_notes[time] = pattern_notes[time] or {}
			table.insert(pattern_notes[time], ubmsc_columns_map[column])
		end
	end

	---@param time integer
	---@return integer?
	local function getPatternKey(time)
		local keys = pattern_notes[time]
		if not keys then
			return
		end
		return table.remove(keys)
	end

	---@type string[]
	local out = {"iBMSC Clipboard Data xNT"}

	for time, line in dpairs(ubmsc_data) do
		local measure = math.floor(time / 192)
		local pattern_line = pattern_notes[time]
		if pattern_line then
			---@type {[integer]: true}
			local processed = {}

			for j, note in ipairs(line) do
				local column = note[1]
				local i = table_util.indexof(pattern_line, column)
				if i then
					table.remove(pattern_line, i)
					processed[j] = true
				end
			end

			for j, note in ipairs(line) do
				local column = note[1]
				if not processed[j] and table_util.indexof(ubmsc_columns_map, column) then
					local key = getPatternKey(time)
					if key then
						note[1] = key
					else
						print("extra note", time, measure, time - measure * 192, table_util.indexof(ubmsc_columns_map, note[1]))
					end
				end
			end

			if next(pattern_line) then
				---@type integer[]
				local columns = {}
				for i, c in ipairs(pattern_line) do
					columns[i] = table_util.indexof(ubmsc_columns_map, c)
				end
				print("not assigned", time, measure, time - measure * 192, table.concat(columns, ","))
			end
		end

		for _, note in ipairs(line) do
			note[2] = note[2] - 192
			table.insert(out, table.concat(note, " "))
		end
	end

	local out_path = path_util.join(real_dir, "iBMSC Clipboard Data xNT out.txt")
	love.filesystem.write(out_path, table.concat(out, "\r\n"))
end

return UbmscExporter
