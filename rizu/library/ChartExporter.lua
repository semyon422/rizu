local ffi = require("ffi")
local class = require("class")
local path_util = require("path_util")
local zip = require("zip")
local ChartEncoder = require("chart.format.osu.ChartEncoder")
local ChartFactory = require("chart.format.notechart.ChartFactory")
local ChartfileReader = require("rizu.library.ChartfileReader")
local ResourceFinder = require("rizu.files.ResourceFinder")
local ResourceLoader = require("rizu.files.ResourceLoader")
local AudioEngine = require("rizu.engine.audio.Engine")
local IidxDecodeContext = require("chart.format.iidx.DecodeContext")
local ModifierModel = require("sphere.models.ModifierModel")
local Wave = require("audio.Wave")

---@class rizu.library.ChartExporter
---@operator call: rizu.library.ChartExporter
local ChartExporter = class()

---@param library rizu.library.Library
function ChartExporter:new(library)
	self.library = library
	self.fs = library.fs
	self.audio_engine_factory = function()
		local engine = AudioEngine()
		engine:setEnabled(true)
		return engine
	end
end

---@param value string?
---@param fallback string
---@return string
local function safeName(value, fallback)
	local name = (value and value ~= "") and value or fallback
	name = name:gsub("[\\/:*?\"<>|]", "_"):gsub("^%.+", "_")
	name = name:gsub("%.+$", "")
	return name ~= "" and name or fallback
end

---@param path string
---@return string?
local function safeArchivePath(path)
	path = path_util.fix_separators(path):gsub("^/+", "")
	if path == "" or path:find("..", 1, true) then
		return nil
	end
	return path
end

---@param chartmeta sea.Chartmeta
---@param index integer
---@return string
local function getOsuName(chartmeta, index)
	local artist = safeName(chartmeta.artist, "Unknown artist")
	local title = safeName(chartmeta.title, "Untitled")
	local creator = safeName(chartmeta.creator, "Unknown creator")
	local version = safeName(chartmeta.name, tostring(index))
	return ("%s - %s (%s) [%s].osu"):format(artist, title, creator, version)
end

---@param wave audio.Wave
---@param start_time number
---@return audio.Wave
local function prependSilence(wave, start_time)
	if start_time <= 0 or wave.samples_count == 0 then
		return wave
	end
	local silence_samples = math.floor(start_time * wave.sample_rate)
	local output = Wave()
	output.sample_rate = wave.sample_rate
	output.bytes_per_sample = wave.bytes_per_sample
	output:initBuffer(wave.channels_count, wave.samples_count + silence_samples)
	ffi.copy(output.byte_ptr + silence_samples * wave.channels_count * wave.bytes_per_sample, wave.byte_ptr, wave:getDataSize())
	return output
end

---@param chart chart.Chart
local function removeChartSounds(chart)
	for _, note in chart.notes:iter() do
		note.data.sounds = {}
	end
end

---@param entries {[string]: string}
---@param name string
---@return string
local function uniqueEntryName(entries, name)
	if not entries[name] then
		return name
	end
	local stem, extension = name:match("^(.*)(%.[^.]*)$")
	stem = stem or name
	extension = extension or ""
	local index = 2
	local candidate = ("%s (%d)%s"):format(stem, index, extension)
	while entries[candidate] do
		index = index + 1
		candidate = ("%s (%d)%s"):format(stem, index, extension)
	end
	return candidate
end

---@param data string
---@return string
local function detectAudioExtension(data)
	if data:sub(1, 4) == "RIFF" then
		return "wav"
	elseif data:sub(1, 4) == "OggS" then
		return "ogg"
	elseif data:sub(1, 3) == "ID3" or data:sub(1, 2) == string.char(0xff, 0xfb) then
		return "mp3"
	elseif data:sub(1, 16) == string.char(
		0x30, 0x26, 0xb2, 0x75, 0x8e, 0x66, 0xcf, 0x11,
		0xa6, 0xd9, 0x00, 0xaa, 0x00, 0x62, 0xce, 0x6c
	) then
		return "wma"
	end
	return "bin"
end

---@param name string
---@param data string
---@return string
local function getKeysoundEntryName(name, data)
	local safe_name = safeArchivePath(name)
	if safe_name and safe_name:match("%.[^./]+$") then
		return safe_name
	end
	local stem = safeName(safe_name or name, "keysound")
	return path_util.join("keysounds", stem .. "." .. detectAudioExtension(data))
end

---@param writer zip.Writer
---@param entries {[string]: string}
---@param name string
---@param data string
local function addEntry(writer, entries, name, data)
	if entries[name] then
		assert(entries[name] == data, "conflicting OSZ entry: " .. name)
		return
	end
	entries[name] = data
	writer:add(name, data)
end

---@param writer zip.Writer
---@param entries {[string]: string}
---@param fs fs.IFilesystem
---@param loader rizu.ResourceLoader
---@param chart chart.Chart
local function addResources(writer, entries, fs, loader, chart)
	for resource_type, paths in chart.resources:iter() do
		if resource_type ~= "ojm" and resource_type ~= "s3p" and resource_type ~= "2dx" then
			local name = safeArchivePath(paths[1])
			local data = loader:getResource(paths[1])
			local resource_path = loader.file_paths[paths[1]]
			if not data and resource_path then
				data = ChartfileReader.read(fs, resource_path)
			end
			if name and data then
				addEntry(writer, entries, name, data)
			end
		end
	end
end

---@param writer zip.Writer
---@param entries {[string]: string}
---@param loader rizu.ResourceLoader
---@param chart chart.Chart
local function addReferencedSounds(writer, entries, loader, chart)
	---@type {[string]: string}
	local renamed_sounds = {}
	for _, note in chart.notes:iter() do
		local sounds = note.data.sounds
		if sounds then
			for _, sound in ipairs(sounds) do
				local name = sound[1]
				local data = loader:getResource(name)
				if data then
					local entry_name = renamed_sounds[name]
					if not entry_name then
						local preferred_name = getKeysoundEntryName(name, data)
						if entries[preferred_name] == data then
							entry_name = preferred_name
						else
							entry_name = uniqueEntryName(entries, preferred_name)
							addEntry(writer, entries, entry_name, data)
						end
						renamed_sounds[name] = entry_name
					end
					sound[1] = entry_name
				end
			end
		end
	end
end

---@param chart chart.Chart
---@param loader rizu.ResourceLoader
---@param audio_engine_factory fun(): rizu.audio.Engine
---@return string
local function compileAudio(chart, loader, audio_engine_factory)
	local engine = audio_engine_factory()
	engine:load(chart, loader.resources, true)
	local start_time = engine:getStartTime()
	local wave = prependSilence(engine:renderWave(), start_time)
	engine:unload()
	assert(wave.samples_count > 0, "chart has no exportable audio")
	return wave:encode()
end

---@param chartSelector rizu.select.ChartSelector
---@param replayBase sea.ReplayBase
function ChartExporter:exportToOsu(chartSelector, replayBase)
	local chartview = chartSelector.chartview
	if not chartview then
		return
	end

	local chart, chartmeta = chartSelector:loadChartAbsolute()
	if not chart or not chartmeta then
		return
	end
	ModifierModel:apply(replayBase.modifiers, chart)

	local data = ChartEncoder():encode({{chart = chart, chartmeta = chartmeta}})
	local file_name = getOsuName(chartmeta, chartview.index or 1)
	assert(self.fs:createDirectory("userdata/export") or self.fs:getInfo("userdata/export"))
	assert(self.fs:write("userdata/export/" .. file_name, data))
end

---@param chartview rizu.library.LocatedChartview
---@param compile_keysounds boolean?
---@return string? path
function ChartExporter:exportToOsz(chartview, compile_keysounds)
	if not chartview or not chartview.chartfile_set_id then
		return
	end

	local chartfile_set = assert(self.library.chartfilesRepo:selectChartfileSetById(chartview.chartfile_set_id))
	local chartfiles = self.library.chartfilesRepo:selectChartfilesBySet(chartview.chartfile_set_id)
	local writer = zip.Writer()
	---@type {[string]: string}
	local entries = {}
	local chart_index = 0

	for _, chartfile in ipairs(chartfiles) do
		---@type rizu.library.LocatedChartfile
		local located_chartfile = chartfile
		located_chartfile.location_id = chartfile_set.location_id
		located_chartfile.set_is_file = chartfile_set.is_file
		located_chartfile.set_dir = chartfile_set.dir
		located_chartfile.set_name = chartfile_set.name
		located_chartfile.chartfile_name = chartfile.name
		located_chartfile.dir = chartfile_set.is_file and chartfile_set.dir or path_util.join(chartfile_set.dir, chartfile_set.name)
		located_chartfile.path = path_util.join(located_chartfile.dir, chartfile.name)
		self.library:enrichChartview(located_chartfile)
		local content = assert(ChartfileReader.read(self.fs, located_chartfile.location_path))
		local chart_chartmetas = assert(ChartFactory:getCharts(
			located_chartfile.chartfile_name,
			content,
			located_chartfile.hash,
			IidxDecodeContext.fromLocation(self.fs, located_chartfile.location_prefix, located_chartfile.chartfile_name)
		))

		local finder = ResourceFinder(self.fs)
		finder:addPath(located_chartfile.location_dir)
		local loader = ResourceLoader(self.fs, finder)

		for _, chart_chartmeta in ipairs(chart_chartmetas) do
			chart_index = chart_index + 1
			local chart = chart_chartmeta.chart
			local chartmeta = chart_chartmeta.chartmeta
			chart.layers.main:toAbsolute()
			loader:load(chart.resources)

			if compile_keysounds then
				local audio_name = ("audio-%d.wav"):format(chart_index)
				addEntry(writer, entries, audio_name, compileAudio(chart, loader, self.audio_engine_factory))
				chartmeta.audio_path = audio_name
				removeChartSounds(chart)
			else
				addResources(writer, entries, self.fs, loader, chart)
				addReferencedSounds(writer, entries, loader, chart)
			end

			local osu_name = uniqueEntryName(entries, getOsuName(chartmeta, chart_index))
			addEntry(writer, entries, osu_name, ChartEncoder():encode({chart_chartmeta}))
		end
	end

	assert(chart_index > 0, "chart set contains no charts")
	local set_name = safeName(chartfile_set.name, "chart-set")
	local path = "userdata/export/" .. set_name .. (compile_keysounds and "-compiled.osz" or ".osz")
	assert(self.fs:createDirectory("userdata/export") or self.fs:getInfo("userdata/export"))
	assert(self.fs:write(path, writer:finish()))
	return path
end

---@param chartSelector rizu.select.ChartSelector
---@param compile_keysounds boolean?
---@return string? path
function ChartExporter:exportSelectedSetToOsz(chartSelector, compile_keysounds)
	return self:exportToOsz(chartSelector.chartview, compile_keysounds)
end

return ChartExporter
