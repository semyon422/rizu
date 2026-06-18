local IDecoder = require("rizu.engine.audio.IDecoder")
local SoftwareMixer = require("rizu.engine.audio.SoftwareMixer")
local ResourceFinder = require("rizu.files.ResourceFinder")
local LazyDecoder = require("rizu.engine.audio.LazyDecoder")
local LazyDataDecoder = require("rizu.engine.audio.LazyDataDecoder")
local LazyS3PDecoder = require("rizu.engine.audio.LazyS3PDecoder")
local OJM = require("chart.format.o2jam.OJM")
local S3P = require("chart.format.iidx.S3P")
local TwoDx = require("chart.format.iidx.TwoDx")
local ChartfileReader = require("rizu.library.ChartfileReader")

---@class rizu.audio.PreviewDecoder: rizu.audio.IDecoder
---@operator call: rizu.audio.PreviewDecoder
---@field private mixer rizu.audio.SoftwareMixer
local PreviewDecoder = IDecoder + {}

---@param fs fs.IFilesystem
---@param dir string
---@param preview rizu.preview.AudioPreview
---@param decoder_factory fun(data: string): rizu.audio.IDecoder
function PreviewDecoder:new(fs, dir, preview, decoder_factory)
	local rf = ResourceFinder(fs)
	rf:addPath(dir)

	local is_ojm = preview.samples[1] and preview.samples[1]:lower():match("%.ojm$")
	if is_ojm then
		return self:newOjm(fs, rf, preview, decoder_factory)
	end
	local is_s3p = preview.samples[1] and preview.samples[1]:lower():match("%.s3p$")
	if is_s3p then
		return self:newS3p(fs, rf, preview, decoder_factory)
	end
	local is_two_dx = preview.samples[1] and preview.samples[1]:lower():match("%.2dx$")
	if is_two_dx then
		return self:newTwoDx(fs, rf, preview, decoder_factory)
	end

	return self:newFiles(fs, rf, preview, decoder_factory)
end

---@param fs fs.IFilesystem
---@param rf rizu.ResourceFinder
---@param preview rizu.preview.AudioPreview
---@param decoder_factory fun(data: string): rizu.audio.IDecoder
function PreviewDecoder:newOjm(fs, rf, preview, decoder_factory)
	local ojm_filename = preview.samples[1]

	---@type o2jam.OJM?
	local ojm
	local path = rf:findFile(ojm_filename, "ojm")
	if path then
		local data = fs:read(path)
		if data then
			ojm = OJM(data)
		end
	end

	if not ojm then
		print("PreviewDecoder: could not load OJM " .. tostring(ojm_filename))
		self.mixer = SoftwareMixer({}, {})
		return
	end

	-- Probe first sound to determine output format
	local sample_rate, channels, bytes_per_sample = 44100, 2, 2
	for i, event in ipairs(preview.events) do
		local sample_data = ojm.samples[event.sample_index - 1]
		if sample_data then
			local dec = decoder_factory(sample_data)
			sample_rate = dec:getSampleRate()
			channels = dec:getChannelCount()
			bytes_per_sample = dec:getBytesPerSample()
			dec:release()
			break
		end
	end

	local sounds = {}
	local decoders = {}
	for i, event in ipairs(preview.events) do
		local sample_data = ojm.samples[event.sample_index - 1]
		if sample_data then
			table.insert(sounds, {time = event.time})
			table.insert(decoders, LazyDataDecoder(
				sample_data, decoder_factory,
				event.duration, sample_rate, channels, bytes_per_sample,
				event.volume
			))
		end
	end

	self.mixer = SoftwareMixer(sounds, decoders)
end

---@param fs fs.IFilesystem
---@param rf rizu.ResourceFinder
---@param preview rizu.preview.AudioPreview
---@param decoder_factory fun(data: string): rizu.audio.IDecoder
function PreviewDecoder:newS3p(fs, rf, preview, decoder_factory)
	local s3p_filename = preview.samples[1]

	---@type chart.iidx.S3PPack?
	local pack
	local path = rf:findFile(s3p_filename, "s3p")
	if path then
		local data = ChartfileReader.read(fs, path)
		if data then
			pack = S3P.parse(data)
		end
	end

	if not pack then
		print("PreviewDecoder: could not load S3P " .. tostring(s3p_filename))
		self.mixer = SoftwareMixer({}, {})
		return
	end

	local sounds = {}
	local decoders = {}
	for _, event in ipairs(preview.events) do
		if S3P.sample_payload_by_id(pack, event.sample_index) then
			table.insert(sounds, {time = event.time})
			table.insert(decoders, LazyS3PDecoder(
				pack, event.sample_index, decoder_factory,
				event.duration, 44100, 2, 2,
				event.volume
			))
		end
	end

	self.mixer = SoftwareMixer(sounds, decoders)
end

---@param fs fs.IFilesystem
---@param rf rizu.ResourceFinder
---@param preview rizu.preview.AudioPreview
---@param decoder_factory fun(data: string): rizu.audio.IDecoder
function PreviewDecoder:newTwoDx(fs, rf, preview, decoder_factory)
	local two_dx_filename = preview.samples[1]

	---@type chart.iidx.TwoDxArchive?
	local archive
	local path = rf:findFile(two_dx_filename, "2dx")
	if path then
		local data = ChartfileReader.read(fs, path)
		if data then
			archive = TwoDx.parse(data)
		end
	end

	if not archive then
		print("PreviewDecoder: could not load 2DX " .. tostring(two_dx_filename))
		self.mixer = SoftwareMixer({}, {})
		return
	end

	local sample_rate, channels, bytes_per_sample = 44100, 2, 2
	for _, event in ipairs(preview.events) do
		local sample_data = TwoDx.payload(archive, event.sample_index)
		if sample_data then
			local dec = decoder_factory(sample_data)
			sample_rate = dec:getSampleRate()
			channels = dec:getChannelCount()
			bytes_per_sample = dec:getBytesPerSample()
			dec:release()
			break
		end
	end

	local sounds = {}
	local decoders = {}
	for _, event in ipairs(preview.events) do
		local sample_data = TwoDx.payload(archive, event.sample_index)
		if sample_data then
			table.insert(sounds, {time = event.time})
			table.insert(decoders, LazyDataDecoder(
				sample_data, decoder_factory,
				event.duration, sample_rate, channels, bytes_per_sample,
				event.volume
			))
		end
	end

	self.mixer = SoftwareMixer(sounds, decoders)
end

---@param fs fs.IFilesystem
---@param rf rizu.ResourceFinder
---@param preview rizu.preview.AudioPreview
---@param decoder_factory fun(data: string): rizu.audio.IDecoder
function PreviewDecoder:newFiles(fs, rf, preview, decoder_factory)
	-- Default format, will be updated if at least one sound is found
	local sample_rate, channels, bytes_per_sample = 44100, 2, 2

	-- Pre-find actual paths to avoid repeated searches
	---@type {[integer]: string}
	local sample_to_actual = {}
	for i, sample_path in ipairs(preview.samples) do
		sample_to_actual[i] = rf:findFile(sample_path, "audio")
	end

	-- Probe first sound to determine output format
	for i, event in ipairs(preview.events) do
		local actual_path = sample_to_actual[event.sample_index]
		if actual_path then
			local data = fs:read(actual_path)
			if data then
				local dec = decoder_factory(data)
				sample_rate = dec:getSampleRate()
				channels = dec:getChannelCount()
				bytes_per_sample = dec:getBytesPerSample()
				dec:release()
				break
			end
		end
	end

	local sounds = {}
	local decoders = {}
	for i, event in ipairs(preview.events) do
		local actual_path = sample_to_actual[event.sample_index]
		if actual_path then
			table.insert(sounds, {time = event.time})
			table.insert(decoders, LazyDecoder(
				fs, actual_path, decoder_factory,
				event.duration, sample_rate, channels, bytes_per_sample,
				event.volume
			))
		end
	end

	self.mixer = SoftwareMixer(sounds, decoders)
end

function PreviewDecoder:getData(buf, len) return self.mixer:getData(buf, len) end
function PreviewDecoder:getSampleRate() return self.mixer:getSampleRate() end
function PreviewDecoder:getChannelCount() return self.mixer:getChannelCount() end
function PreviewDecoder:getBytesPerSample() return self.mixer:getBytesPerSample() end
function PreviewDecoder:getDuration() return self.mixer:getDuration() end
function PreviewDecoder:getBytesDuration() return self.mixer:getBytesDuration() end
function PreviewDecoder:getBytesPosition() return self.mixer:getBytesPosition() end
function PreviewDecoder:getPosition() return self.mixer:getPosition() end

function PreviewDecoder:setBytesPosition(pos)
	self.mixer:setBytesPosition(pos)
end

function PreviewDecoder:setPosition(pos)
	self.mixer:setPosition(pos)
end

function PreviewDecoder:secondsToBytes(s) return self.mixer:secondsToBytes(s) end
function PreviewDecoder:bytesToSeconds(b) return self.mixer:bytesToSeconds(b) end

function PreviewDecoder:release()
	self.mixer:release()
end

return PreviewDecoder
