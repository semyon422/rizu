local class = require("class")
local path_util = require("path_util")
local string_util = require("string_util")
local table_util = require("table_util")
local ChartDecoder = require("chart.format.sph.ChartDecoder")
local base36 = require("chart.format.bms.base36")
local md5 = require("md5")

---@class rizu.editor.exports.BmsTemplateExporter
---@operator call: rizu.editor.exports.BmsTemplateExporter
local BmsTemplateExporter = class()

local bms_columns = {
	[5] = {11, 12, 13, 14, 15},
	[7] = {11, 12, 13, 14, 15, 18, 19},
	[10] = {11, 12, 13, 14, 15, 21, 22, 23, 24, 25},
}

---@param notes chartedit.Notes
---@param sounds_map {[string]: integer}
---@return {[number]: {[1]: integer, [2]: integer?}[]}
local function getPatternNotes(notes, sounds_map)
	local linkedNotes = notes:getLinkedNotes()

	---@type {[number]: integer[]}
	local pattern_notes = {}

	for i = 1, #linkedNotes - 1 do
		local key = tonumber(linkedNotes[i]:getColumn():match("^key(.+)$"))
		if key then
			local note = linkedNotes[i].startNote
			local p = note.visualPoint.point
			---@cast p chartedit.Point

			local sound = note.data.sounds and note.data.sounds[1] and note.data.sounds[1][1]
			local time = p:getGlobalTime():tonumber()
			pattern_notes[time] = pattern_notes[time] or {}
			table.insert(pattern_notes[time], {key, sounds_map[sound]})
		end
	end

	return pattern_notes
end

---@param chartSelector rizu.select.ChartSelector
---@param editorModel rizu.editor.EditorModel
---@param columns_out number
function BmsTemplateExporter:export(chartSelector, editorModel, columns_out)
	local chartview = chartSelector.chartview
	local real_dir = chartview.real_dir

	---@type chart.Chart[]
	local stem_charts = {}

	for _, name in ipairs(love.filesystem.getDirectoryItems(real_dir) --[=[@as string[]]=]) do
		if name:match("^stem.+%.sph$") then
			local dec = ChartDecoder()
			local data = assert(love.filesystem.read(path_util.join(real_dir, name)))
			local chart = dec:decode(data, md5.sumhexa(data))[1]
			chart.name = name
			table.insert(stem_charts, chart)
		end
	end

	---@type string[]
	local sounds = {}
	---@type {[string]: integer}
	local sounds_map = {}

	---@param path string
	local function get_sound_index(path)
		if sounds_map[path] then
			return sounds_map[path]
		end
		table.insert(sounds, path)
		sounds_map[path] = #sounds
		return sounds_map[path]
	end

	---@type number
	local tempo
	---@type {time: chart.Fraction, column: integer, sound: integer}[]
	local notes = {}
	---@type chart.Fraction
	local max_time

	local beat_offset = editorModel.bmsToolsContext.beat_offset

	for column, chart in ipairs(stem_charts) do
		local dir = chart.chartmeta.name
		local linkedNotes = chart.notes:getLinkedNotes()

		local ks_index = 1
		for i = 1, #linkedNotes - 1 do
			local key = tonumber(linkedNotes[i]:getColumn():match("^key(.+)$"))
			if key then
				local n_a = linkedNotes[i]
				---@type string?
				local comment = n_a.startNote.visualPoint.comment

				local file_name = ks_index .. ".wav"
				if comment then
					local new_index = tonumber(comment:match("^=(.+)$"))
					if new_index then
						ks_index = new_index
						file_name = ks_index .. ".wav"
					else
						file_name = comment .. ".wav"
					end
				end

				local path = path_util.join(dir, file_name)
				ks_index = ks_index + 1

				local point = n_a.startNote.visualPoint.point
				---@cast point chart.IntervalPoint

				if not tempo then
					tempo = point.vertex:getTempo()
				end

				local time = point.time + beat_offset
				table.insert(notes, {
					time = time,
					column = column,
					sound = get_sound_index(path),
					chart_name = chart.name,
				})

				if not max_time or time > max_time then
					max_time = time
				end
			end
		end
	end

	if #sounds > 36 ^ 2 - 1 then
		print("too much sounds")
		return
	end

	---@type {[integer]: {[integer]: {time: chart.Fraction, sound: integer}[]}}
	local notes_grouped = {}
	---@type {[integer]: {[integer]: {time: chart.Fraction, sound: integer}[]}}
	local play_notes_grouped = {}

	local pattern_notes = getPatternNotes(editorModel.notes, sounds_map)

	---@param time chart.Fraction
	---@param sound integer
	---@return integer?
	local function getPatternKey(time, sound)
		local keys = pattern_notes[(time - beat_offset):tonumber()]
		if not keys then
			return
		end
		local i
		for j, key_sound in ipairs(keys) do
			if key_sound[2] == sound then
				i = j
				break
			end
		end
		if not i then
			return
		end
		local key_sound = table.remove(keys, i)
		if not key_sound then
			return
		end
		return key_sound[1]
	end

	local always_bgm = {}
	do
		local data = love.filesystem.read(path_util.join(real_dir, "bgm.txt"))
		if data then
			for _, line in string_util.isplit(data, "\n") do
				line = string_util.trim(line)
				always_bgm[line] = true
			end
		end
	end

	for _, note in ipairs(notes) do
		local measure = (note.time / 4):floor()
		local key
		if not always_bgm[note.chart_name] then
			key = getPatternKey(note.time, note.sound)
		end

		local t, k
		if not key then
			t = notes_grouped
			k = note.column
		else
			t = play_notes_grouped
			k = key
		end

		t[measure] = t[measure] or {}
		t[measure][k] = t[measure][k] or {}
		table.insert(t[measure][k], {
			time = note.time / 4 - measure,
			sound = note.sound,
		})
	end

	---@type string[]
	local lines = {
		"",
		"*---------------------- HEADER FIELD",
		"",
		"#PLAYER 1",
		("#TITLE %s"):format(chartview.title),
		("#ARTIST %s"):format(chartview.artist),
		("#SUBARTIST OBJ: %s"):format(chartview.creator),
		("#BPM %s"):format(tempo),
		"#PLAYLEVEL 5",
		"#RANK 3",
		("#TOTAL %s"):format(#notes),
		"#STAGEFILE title.bmp",
		"",
	}

	for i, path in ipairs(sounds) do
		table.insert(lines, ("#WAV%s %s"):format(base36.tostring(i), path))
	end

	table.insert(lines, "")

	local max_measure = (max_time / 4):ceil()
	local snap = 384
	local play_channels = bms_columns[columns_out]

	for measure = 0, max_measure do
		if notes_grouped[measure] then
			for column = 1, table.maxn(notes_grouped[measure]) do
				local column_notes = notes_grouped[measure][column]
				if not column_notes then
					table.insert(lines, ("#%03d01:00"):format(measure))
				else
					---@type string[]
					local value = {}
					for i = 1, snap do
						value[i] = "00"
					end
					for _, note in ipairs(column_notes) do
						local time = (note.time * snap):floor() + 1
						value[time] = base36.tostring(note.sound)
					end
					table.insert(lines, ("#%03d01:%s"):format(measure, table.concat(value)))
				end
			end
			table.insert(lines, "")
		end

		if play_notes_grouped[measure] then
			for column = 1, table.maxn(play_notes_grouped[measure]) do
				local column_notes = play_notes_grouped[measure][column]
				if column_notes then
					---@type string[]
					local value = {}
					for i = 1, snap do
						value[i] = "00"
					end
					for _, note in ipairs(column_notes) do
						local time = (note.time * snap):floor() + 1
						value[time] = base36.tostring(note.sound)
					end
					local ch = play_channels[column]
					table.insert(lines, ("#%03d%02d:%s"):format(measure, ch, table.concat(value)))
				end
			end
		end
	end

	local out_path = path_util.join(real_dir, "template.bme")
	love.filesystem.write(out_path, table.concat(lines, "\r\n"))
end

return BmsTemplateExporter
