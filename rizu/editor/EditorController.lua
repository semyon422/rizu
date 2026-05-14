local class = require("class")
local dpairs = require("dpairs")
local path_util = require("path_util")
local table_util = require("table_util")
local string_util = require("string_util")
local ChartEncoder = require("sph.ChartEncoder")
local ChartDecoder = require("sph.ChartDecoder")
local BmsChartDecoder = require("bms.ChartDecoder")
local OsuChartEncoder = require("osu.ChartEncoder")
local NanoChart = require("libchart.NanoChart")
local InputMode = require("ncdk.InputMode")
local zlib = require("zlib")
local SphPreview = require("sph.SphPreview")
local ModifierModel = require("sphere.models.ModifierModel")
local Wave = require("audio.Wave")
local base36 = require("bms.base36")
local decibel = require("decibel")
local md5 = require("md5")

---@class rizu.editor.EditorController
---@operator call: rizu.editor.EditorController
local EditorController = class()

---@param chartSelector rizu.select.ChartSelector
---@param editorModel rizu.editor.EditorModel
---@param noteSkinModel sphere.NoteSkinModel
---@param configModel sphere.ConfigModel
---@param resourceModel sphere.ResourceModel
---@param windowModel sphere.WindowModel
---@param library rizu.library
---@param fileFinder sphere.FileFinder
---@param previewModel rizu.preview.PreviewModel
---@param replayBase sea.ReplayBase
---@param resource_finder rizu.ResourceFinder
---@param resource_loader rizu.ResourceLoader
function EditorController:new(
	chartSelector,
	editorModel,
	noteSkinModel,
	configModel,
	resourceModel,
	windowModel,
	library,
	fileFinder,
	previewModel,
	replayBase,
	resource_finder,
	resource_loader
)
	self.chartSelector = chartSelector
	self.editorModel = editorModel
	self.noteSkinModel = noteSkinModel
	self.configModel = configModel
	self.resourceModel = resourceModel
	self.windowModel = windowModel
	self.library = library
	self.fileFinder = fileFinder
	self.previewModel = previewModel
	self.replayBase = replayBase
	self.resource_finder = resource_finder
	self.resource_loader = resource_loader
end

function EditorController:load()

	local chartSelector = self.chartSelector
	local editorModel = self.editorModel
	local configModel = self.configModel
	local fileFinder = self.fileFinder

	local chart, chartmeta = chartSelector:loadChart()

	if love.keyboard.isDown("lshift") then
		ModifierModel:apply(self.replayBase.modifiers, chart)
	end

	local chartview = chartSelector.chartview

	local noteSkin = self.noteSkinModel:loadNoteSkin(tostring(chart.inputMode))
	noteSkin:loadData()
	noteSkin.editor = true

	editorModel.noteSkin = noteSkin
	editorModel.chart = chart
	editorModel.chartmeta = chartmeta
	editorModel:load()

	self.previewModel:stop()

	local paths = {}
	if configModel.configs.settings.gameplay.skin_resources_top_priority then
		table.insert(paths, noteSkin.directoryPath)
		table.insert(paths, chartview.location_dir)
	else
		table.insert(paths, chartview.location_dir)
		table.insert(paths, noteSkin.directoryPath)
	end
	table.insert(paths, "userdata/hitsounds")
	table.insert(paths, "userdata/hitsounds/midi")

	fileFinder:reset()
	self.resource_finder:reset()
	for _, path in ipairs(paths) do
		fileFinder:addPath(path)
		self.resource_finder:addPath(path)
	end

	self.resource_loader:load(chart.resources)

	self.resourceModel:load(chart, function()
		editorModel:loadResources(self.resource_loader.resources)
	end)

	self.windowModel:setVsyncOnSelect(false)
end

function EditorController:unload()
	self.editorModel:unload()

	self.windowModel:setVsyncOnSelect(true)
end

function EditorController:sliceKeysounds()
	local chartSelector = self.chartSelector

	---@type rizu.editor.EditorModel
	local editorModel = self.editorModel

	---@type audio.Wave
	local wave_full = editorModel.audio_engine:renderWave()
	if not wave_full then
		return
	end

	local volume = editorModel.metadata:get("volume") or "1"
	local mulVolume = tonumber(volume)
	local dbVolume = tonumber(volume:lower():match("^(.+)%s*db$"))
	if mulVolume then
		volume = mulVolume
	elseif dbVolume then
		volume = decibel.lf_to_f(dbVolume)
	end

	print("volume", volume)

	local chartview = chartSelector.chartview
	local real_dir = chartview.real_dir

	local dir = path_util.join(real_dir, chartview.name)
	assert(love.filesystem.createDirectory(dir))

	---@type chartedit.Notes
	local notes = editorModel.notes

	local linkedNotes = notes:getLinkedNotes()

	local sample_rate = wave_full.sample_rate
	local channels_count = wave_full.channels_count

	print("sample rate", sample_rate)

	---@param wave audio.Wave
	local function fade_in(wave)
		local dur = 0.002
		local samples_dur = math.floor(dur * wave.sample_rate)
		for i = 0, samples_dur - 1 do
			for c = 1, wave.channels_count do
				wave:setSampleFloat(i, c, wave:getSampleFloat(i, c) * i / samples_dur)
			end
		end
	end

	---@param wave audio.Wave
	local function fade_out(wave)
		local dur = 0.002
		local samples_dur = math.floor(dur * wave.sample_rate)
		for i = 0, samples_dur - 1 do
			for c = 1, wave.channels_count do
				wave:setSampleFloat(wave.samples_count - samples_dur + i, c, wave:getSampleFloat(wave.samples_count - samples_dur + i, c) * (samples_dur - i) / samples_dur)
			end
		end
	end

	local ks_index = 1
	for i = 1, #linkedNotes - 1 do
		local key = tonumber(linkedNotes[i]:getColumn():match("^key(.+)$"))
		if key then
			---@type number, number
			local a, b
			local n_a, n_b = linkedNotes[i], linkedNotes[i + 1]
			if n_a:isShort() then
				a, b = n_a:getStartTime(), n_b:getStartTime()
			else
				a, b = n_a:getStartTime(), n_a:getEndTime()
			end

			local sample_offset = math.floor(a * sample_rate)
			local sample_count = math.floor((b - a) * sample_rate)

			local wave = Wave()
			wave.sample_rate = sample_rate
			wave:initBuffer(channels_count, sample_count)

			for j = 0, sample_count - 1 do
				for c = 1, channels_count do
					local sample = wave_full:getSampleFloat(math.min(sample_offset + j, wave_full.samples_count - 1), c)
					wave:setSampleFloat(j, c, sample * volume)
				end
			end

			-- fade_in(wave)
			-- fade_out(wave)

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

			local note = n_a.startNote

			local p = note.visualPoint.point
			---@cast p chartedit.Point

			print(p, file_name)
			note.data.sounds = {{path_util.join(chartview.name, file_name), 1}}

			local path = path_util.join(dir, file_name)
			love.filesystem.write(path, wave:encode())
			ks_index = ks_index + 1
		end
	end
end

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
			---@type number, number
			local a, b
			local n_a, n_b = linkedNotes[i], linkedNotes[i + 1]

			local note = n_a.startNote

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

local ubmsc_columns = {
	["10key"] = {6, 7, 8, 9, 10, 14, 15, 16, 17, 18},
}

function EditorController:exportUBmsC()
	local chartSelector = self.chartSelector
	local editorModel = self.editorModel

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

local bms_columns = {
	[5] = {11, 12, 13, 14, 15},
	[7] = {11, 12, 13, 14, 15, 18, 19},
	[10] = {11, 12, 13, 14, 15, 21, 22, 23, 24, 25},
}

function EditorController:exportBmsTemplate(columns_out)
	local chartSelector = self.chartSelector
	local editorModel = self.editorModel

	local chartview = chartSelector.chartview
	local real_dir = chartview.real_dir

	---@type ncdk2.Chart[]
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

	print(#stem_charts)

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

	---@type {time: ncdk.Fraction, column: integer, sound: integer}[]
	local notes = {}

	---@type ncdk.Fraction
	local max_time

	local beat_offset = editorModel.bms_tools.beat_offset

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
				---@cast point ncdk2.IntervalPoint

				if not tempo then
					tempo = point.interval:getTempo()
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

	print("sounds", #sounds)
	if #sounds > 36 ^ 2 - 1 then
		print("too much sounds")
		return
	end

	---@type {[integer]: {[integer]: {time: ncdk.Fraction, sound: integer}[]}}
	local notes_grouped = {}

	---@type {[integer]: {[integer]: {time: ncdk.Fraction, sound: integer}[]}}
	local play_notes_grouped = {}

	-- local pattern_notes = {}
	local pattern_notes = getPatternNotes(editorModel.notes, sounds_map)

	---@param time ncdk.Fraction
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
				print("bgm", line)
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

function EditorController:save()
	local chartSelector = self.chartSelector
	local editorModel = self.editorModel

	self.editorModel:save()
	self.editorModel:genGraphs()

	local encoder = ChartEncoder()
	local data = encoder:encode({{
		chart = editorModel.chart,
		chartmeta = editorModel.chartmeta,
	}})

	local chartview = chartSelector.chartview
	local path = chartview.location_path:gsub(".sph$", "") .. ".sph"

	assert(love.filesystem.write(path, data))

	self.library:computeLocation(chartview.dir, chartview.location_id)
end

function EditorController:saveToOsu()
	local chartSelector = self.chartSelector
	local editorModel = self.editorModel

	self.editorModel:save()

	local encoder = OsuChartEncoder()
	local data = encoder:encode({{
		chart = editorModel.chart,
		chartmeta = editorModel.chartmeta,
	}})

	local chartview = chartSelector.chartview
	local path = chartview.location_path:gsub(".osu$", ""):gsub(".sph$", "") .. ".sph.osu"

	assert(love.filesystem.write(path, data))
end

function EditorController:saveToNanoChart()
	local chartSelector = self.chartSelector
	local editorModel = self.editorModel

	self.editorModel:save()

	local nanoChart = NanoChart()

	local abs_notes = {}

	for noteDatas, inputType, inputIndex, layerDataIndex in editorModel.noteChart:getInputIterator() do
		for _, noteData in ipairs(noteDatas) do
			if inputType == "key" and (noteData.noteType == "ShortNote" or noteData.noteType == "LongNoteStart") then
				abs_notes[#abs_notes + 1] = {
					time = noteData.timePoint.absoluteTime,
					type = 1,
					input = 1,
				}
			end
		end
	end

	local emptyHash = string_util.char(0):rep(16)
	local content = nanoChart:encode(emptyHash, editorModel.noteChart.inputMode.key, abs_notes)
	local compressedContent = zlib.compress(content)

	local chartview = chartSelector.chartview

	local path = chartview.real_path

	local f = assert(io.open(path .. ".nanochart_compressed", "w"))
	f:write(compressedContent)
	f:close()
	local f = assert(io.open(path .. ".nanochart", "w"))
	f:write(content)
	f:close()

	local exp = NoteChartExporter()
	exp.noteChart = editorModel.noteChart
	local sph_chart = exp:export()

	local content = SphPreview:encodeLines(exp.sph.sphLines:encode())
	local compressedContent = zlib.compress(content)

	local content1 = SphPreview:encodeLines(exp.sph.sphLines:encode(), 1)
	local compressedContent1 = zlib.compress(content1)

	local f = assert(io.open(path .. ".preview0_compressed", "w"))
	f:write(compressedContent)
	f:close()
	local f = assert(io.open(path .. ".preview0", "w"))
	f:write(content)
	f:close()
	local f = assert(io.open(path .. ".preview1_compressed", "w"))
	f:write(compressedContent1)
	f:close()
	local f = assert(io.open(path .. ".preview1", "w"))
	f:write(content1)
	f:close()
	-- local f = assert(io.open(path .. ".preview_lines", "w"))
	-- f:write(require("inspect")(lines))
	-- f:close()
end

---@param event table
function EditorController:receive(event)
	self.editorModel:receive(event)
	if event.name == "filedropped" then
		self:filedropped(event[1])
	end
end

local exts = {
	mp3 = true,
	ogg = true,
}

---@param file love.File
function EditorController:filedropped(file)
	local path = file:getFilename():gsub("\\", "/")

	local _name, ext = path:match("^(.+)%.(.-)$")
	if not exts[ext] then
		return
	end

	local audioName = _name:match("^.+/(.-)$")
	local chartSetPath = "userdata/charts/editor/" .. os.time() .. " " .. audioName

	love.filesystem.write(chartSetPath .. "/" .. audioName .. "." .. ext, file:read())
end

return EditorController
