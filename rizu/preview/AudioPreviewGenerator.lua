local class = require("class")
local AudioPreview = require("rizu.preview.AudioPreview")
local ResourceFinder = require("rizu.files.ResourceFinder")
local OJM = require("chart.format.o2jam.OJM")
local S3P = require("chart.format.iidx.S3P")
local S3PAudio = require("chart.format.iidx.S3PAudio")
local TwoDx = require("chart.format.iidx.TwoDx")
local ChartfileReader = require("rizu.library.ChartfileReader")

---@class rizu.preview.AudioPreviewGenerator
---@operator call: rizu.preview.AudioPreviewGenerator
local AudioPreviewGenerator = class()

---@param fs fs.IFilesystem
---@param decoder_factory fun(data: string): rizu.audio.IDecoder
function AudioPreviewGenerator:new(fs, decoder_factory)
	self.fs = assert(fs, "missing fs")
	self.decoder_factory = assert(decoder_factory, "missing decoder_factory")
end

---@param finder rizu.ResourceFinder
---@param paths string[]
---@param format rizu.ResourceFormat
---@return string? requested_path
---@return string? found_path
local function find_resource_path(finder, paths, format)
	for _, path in ipairs(paths) do
		local found_path = finder:findFile(path, format)
		if found_path then
			return path, found_path
		end
	end
end

---@param chart chart.Chart
---@param chart_dir string
---@param hash string
function AudioPreviewGenerator:generate(chart, chart_dir, hash)
	local finder = ResourceFinder(self.fs)
	finder:addPath(chart_dir)

	---@type {[string]: string[]}
	local ojm_res = chart.resources.ojm
	if ojm_res then
		local ojm_filename = next(ojm_res)
		---@cast ojm_filename -?
		local ojm_path = finder:findFile(ojm_filename, "ojm")
		if ojm_path then
			local data = self.fs:read(ojm_path)
			if data then
				return self:generateFromOjm(chart, OJM(data), ojm_filename, hash)
			end
		end

		print("AudioPreviewGenerator: OJM file missing or unreadable: " .. tostring(ojm_filename))
		return self:writePreview(AudioPreview(), hash)
	end

	---@type {[string]: string[]}
	local s3p_res = chart.resources.s3p
	local missing_s3p_filename
	if s3p_res then
		local _, s3p_paths = next(s3p_res)
		---@cast s3p_paths string[]
		local s3p_filename, s3p_path = find_resource_path(finder, s3p_paths, "s3p")
		if s3p_path then
			local data = ChartfileReader.read(self.fs, s3p_path)
			if data then
				---@cast s3p_filename -?
				return self:generateFromS3p(chart, S3P.parse(data), s3p_filename, hash)
			end
		end

		missing_s3p_filename = s3p_paths[1]
	end

	---@type {[string]: string[]}
	local two_dx_res = chart.resources["2dx"]
	if two_dx_res then
		local _, two_dx_paths = next(two_dx_res)
		---@cast two_dx_paths string[]
		local two_dx_filename, two_dx_path = find_resource_path(finder, two_dx_paths, "2dx")
		if two_dx_path then
			local data = ChartfileReader.read(self.fs, two_dx_path)
			if data then
				---@cast two_dx_filename -?
				return self:generateFromTwoDx(chart, TwoDx.parse(data), two_dx_filename, hash)
			end
		end

		if missing_s3p_filename then
			print("AudioPreviewGenerator: S3P file missing or unreadable: " .. tostring(missing_s3p_filename))
		end
		print("AudioPreviewGenerator: 2DX file missing or unreadable: " .. tostring(two_dx_paths[1]))
		return self:writePreview(AudioPreview(), hash)
	end

	if missing_s3p_filename then
		print("AudioPreviewGenerator: S3P file missing or unreadable: " .. tostring(missing_s3p_filename))
		return self:writePreview(AudioPreview(), hash)
	end

	return self:generateFromFiles(chart, finder, hash)
end

---@param chart chart.Chart
---@param ojm o2jam.OJM
---@param ojm_filename string
---@param hash string
function AudioPreviewGenerator:generateFromOjm(chart, ojm, ojm_filename, hash)
	local preview = AudioPreview()
	preview.samples = {ojm_filename}
	local sample_durations = {}

	for _, note in ipairs(chart.notes.notes) do
		---@type [any, number][]
		local sounds = note.data.sounds
		if sounds then
			for _, sound_data in ipairs(sounds) do
				local id = tonumber(sound_data[1])
				if id and ojm.samples[id] then
					local duration = self:getOjmDuration(ojm.samples[id], id, sample_durations)
					if duration > 0 then
						table.insert(preview.events, {
							time = note:getTime(),
							sample_index = id + 1,
							duration = duration,
							volume = sound_data[2] or 1,
						})
					end
				end
			end
		end
	end

	self:writePreview(preview, hash)
end

---@param chart chart.Chart
---@param pack chart.iidx.S3PPack
---@param s3p_filename string
---@param hash string
function AudioPreviewGenerator:generateFromS3p(chart, pack, s3p_filename, hash)
	local preview = AudioPreview()
	preview.samples = {s3p_filename}
	local sample_durations = {}

	for _, note in ipairs(chart.notes.notes) do
		---@type [any, number][]
		local sounds = note.data.sounds
		if sounds then
			for _, sound_data in ipairs(sounds) do
				local id = tonumber(sound_data[1])
				local sample_data = id and S3PAudio.payload_by_id(pack, id)
				if id and sample_data then
					local duration = self:getSampleDuration(sample_data, id, sample_durations, "S3P")
					if duration > 0 then
						table.insert(preview.events, {
							time = note:getTime(),
							sample_index = id,
							duration = duration,
							volume = sound_data[2] or 1,
						})
					end
				end
			end
		end
	end

	self:writePreview(preview, hash)
end

---@param chart chart.Chart
---@param archive chart.iidx.TwoDxArchive
---@param two_dx_filename string
---@param hash string
function AudioPreviewGenerator:generateFromTwoDx(chart, archive, two_dx_filename, hash)
	local preview = AudioPreview()
	preview.samples = {two_dx_filename}
	local sample_durations = {}

	for _, note in ipairs(chart.notes.notes) do
		---@type [any, number][]
		local sounds = note.data.sounds
		if sounds then
			for _, sound_data in ipairs(sounds) do
				local id = tonumber(sound_data[1])
				local sample_data = id and TwoDx.payload(archive, id)
				if id and sample_data then
					local duration = self:getSampleDuration(sample_data, id, sample_durations, "2DX")
					if duration > 0 then
						table.insert(preview.events, {
							time = note:getTime(),
							sample_index = id,
							duration = duration,
							volume = sound_data[2] or 1,
						})
					end
				end
			end
		end
	end

	self:writePreview(preview, hash)
end

---@param chart chart.Chart
---@param finder rizu.ResourceFinder
---@param hash string
function AudioPreviewGenerator:generateFromFiles(chart, finder, hash)
	local preview = AudioPreview()
	---@type {[string]: integer}
	local samples_map = {}
	---@type {[string]: number}
	local sample_durations = {}

	local notes = chart.notes.notes
	local audio_notes = {}
	for _, note in ipairs(notes) do
		if note.column == "audio" then
			---@type [any, number][]
			local sounds = note.data.sounds
			if sounds then
				for _, sound_data in ipairs(sounds) do
					local path = sound_data[1]
					if type(path) == "string" and finder:findFile(path, "audio") then
						table.insert(audio_notes, note)
						break
					end
				end
			end
		end
	end

	if #audio_notes > 0 then
		notes = audio_notes
	end

	for _, note in ipairs(notes) do
		---@type [string, number][]
		local sounds = note.data.sounds
		if sounds then
			for _, sound_data in ipairs(sounds) do
				local path = sound_data[1]
				if not samples_map[path] then
					table.insert(preview.samples, path)
					samples_map[path] = #preview.samples
				end

				local duration = self:getDuration(path, finder, sample_durations)
				if duration > 0 then
					table.insert(preview.events, {
						time = note:getTime(),
						sample_index = samples_map[path],
						duration = duration,
						volume = sound_data[2] or 1,
					})
				end
			end
		end
	end

	self:writePreview(preview, hash)
end

---@param preview rizu.preview.AudioPreview
---@param hash string
function AudioPreviewGenerator:writePreview(preview, hash)
	if #preview.events == 0 then
		print("AudioPreviewGenerator: no events generated for " .. hash)
		return
	end

	table.sort(preview.events, function(a, b)
		return a.time < b.time
	end)

	local output_dir = "userdata/audio_previews"
	if not self.fs:getInfo(output_dir) then
		self.fs:createDirectory(output_dir)
	end

	local output_path = output_dir .. "/" .. hash .. ".audio_preview"
	print("AudioPreviewGenerator: writing " .. #preview.events .. " events to " .. output_path)

	self.fs:write(output_path, preview:encode())
end

---@param data string
---@param key string|integer
---@param durs {[string|integer]: number}
---@return number
function AudioPreviewGenerator:getOjmDuration(data, key, durs)
	return self:getSampleDuration(data, key, durs, "OJM")
end

---@param data string
---@param key string|integer
---@param durs {[string|integer]: number}
---@param label string
---@return number
function AudioPreviewGenerator:getSampleDuration(data, key, durs, label)
	if durs[key] then
		return durs[key]
	end

	local ok, decoder = pcall(self.decoder_factory, data)
	if not ok or not decoder then
		print("AudioPreviewGenerator: decoder_factory failed for " .. label .. " sample " .. key .. ": " .. tostring(decoder))
		durs[key] = 0
		return 0
	end

	local duration = decoder:getDuration()
	if duration <= 0 then
		print("AudioPreviewGenerator: zero duration for " .. label .. " sample " .. key)
	end

	durs[key] = duration
	decoder:release()

	return duration
end

---@param path string
---@param finder rizu.ResourceFinder
---@param durs {[string]: number}
---@return number
function AudioPreviewGenerator:getDuration(path, finder, durs)
	if durs[path] then
		return durs[path]
	end

	local full_path = finder:findFile(path, "audio")
	if not full_path then
		print("AudioPreviewGenerator: could not find file " .. tostring(path))
		durs[path] = 0
		return 0
	end

	local data = self.fs:read(full_path)
	if not data then
		print("AudioPreviewGenerator: could not read file " .. tostring(full_path))
		durs[path] = 0
		return 0
	end

	local ok, decoder = pcall(self.decoder_factory, data)
	if not ok or not decoder then
		print("AudioPreviewGenerator: decoder_factory failed for " .. tostring(path) .. ": " .. tostring(decoder))
		durs[path] = 0
		return 0
	end

	local duration = decoder:getDuration()
	if duration <= 0 then
		print("AudioPreviewGenerator: zero duration for " .. tostring(path))
	end

	durs[path] = duration
	decoder:release()

	return duration
end

return AudioPreviewGenerator
