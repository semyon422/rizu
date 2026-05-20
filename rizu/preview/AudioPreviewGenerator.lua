local class = require("class")
local AudioPreview = require("rizu.preview.AudioPreview")
local ResourceFinder = require("rizu.files.ResourceFinder")
local OJM = require("chart.format.o2jam.OJM")

---@class rizu.preview.AudioPreviewGenerator
---@operator call: rizu.preview.AudioPreviewGenerator
local AudioPreviewGenerator = class()

---@param fs fs.IFilesystem
---@param decoder_factory fun(data: string): rizu.audio.IDecoder
function AudioPreviewGenerator:new(fs, decoder_factory)
	self.fs = assert(fs, "missing fs")
	self.decoder_factory = assert(decoder_factory, "missing decoder_factory")
end

---@param chart ncdk2.Chart
---@param chart_dir string
---@param hash string
function AudioPreviewGenerator:generate(chart, chart_dir, hash)
	local finder = ResourceFinder(self.fs)
	finder:addPath(chart_dir)

	---@type {[string]: any}
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

	return self:generateFromFiles(chart, finder, hash)
end

---@param chart ncdk2.Chart
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

---@param chart ncdk2.Chart
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
	if durs[key] then
		return durs[key]
	end

	local ok, decoder = pcall(self.decoder_factory, data)
	if not ok or not decoder then
		print("AudioPreviewGenerator: decoder_factory failed for OJM sample " .. key .. ": " .. tostring(decoder))
		durs[key] = 0
		return 0
	end

	local duration = decoder:getDuration()
	if duration <= 0 then
		print("AudioPreviewGenerator: zero duration for OJM sample " .. key)
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
