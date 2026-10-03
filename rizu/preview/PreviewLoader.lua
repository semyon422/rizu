local class = require("class")
local delay = require("delay")
local thread = require("thread")
local ChartfileReader = require("rizu.library.ChartfileReader")

---@class rizu.preview.PreviewLoader.Media
---@field audio_exists boolean
---@field bga_exists boolean
---@field bga_paths string[]
---@field audio_resource_dir string?

---@alias rizu.preview.PreviewLoader.State "empty"|"loading"|"ready"|"failed"

---Media state describes preparation/dispatch, not asynchronous player readiness.
---@class rizu.preview.PreviewLoader
---@operator call: rizu.preview.PreviewLoader
---@field model rizu.preview.PreviewModel
---@field game sphere.GameController
---@field media_generation integer
---@field media_state rizu.preview.PreviewLoader.State
---@field media_error string?
---@field generate_async fun(data: rizu.preview.PreviewGenerationData): boolean, string?
---@field probe_media fun(chartview: rizu.preview.PreviewChartview): rizu.preview.PreviewLoader.Media
---@field generating_hashes {[string]: boolean?}
---@field attempted_hashes {[string]: boolean?}
---@field repaired_notes {[string]: string}
---@field active_generation_hash string?
---@field pending_generation rizu.preview.PreviewGenerationData?
---@field generation_errors {[string]: string}
---@field released boolean
local PreviewLoader = class()

---@param chartview rizu.preview.PreviewChartview
---@return string?
local function get_preview_resource_dir(chartview)
	local archive_path = chartview.location_path and ChartfileReader.splitArchivePath(chartview.location_path)
	return archive_path or chartview.location_dir
end

local probeMedia = thread.async(function(chartview)
	require("love.filesystem")
	local PreviewMediaProbe = require("rizu.preview.PreviewMediaProbe")
	local LoveFilesystem = require("fs.LoveFilesystem")
	return PreviewMediaProbe(LoveFilesystem()):probe(chartview)
end)

---@param chartview rizu.preview.PreviewChartview|rizu.preview.PreviewGenerationData
---@return string
local function get_notes_key(chartview)
	return chartview.hash .. ":" .. chartview.index .. ":" .. tostring(chartview.chartdiff_id)
end

---@param model rizu.preview.PreviewModel
function PreviewLoader:new(model)
	self.model = model
	self.game = model.game
	self.media_state = "empty"
	self.media_generation = 0
	self.probe_media = probeMedia
	self.generating_hashes = {}
	self.attempted_hashes = {}
	self.generation_errors = {}
	self.repaired_notes = {}
	self.released = false
end

function PreviewLoader:load()
	self.released = false
end

function PreviewLoader:loadPreviewDebounce()
	self.media_generation = self.media_generation + 1
	self.media_state = "loading"
	self.media_error = nil
	if not self.model.active or self.released then return end
	delay.debounce(self, "loadDebounce", 0.1, self.loadPreviewSafe, self)
end

function PreviewLoader:loadPreviewSafe()
	local generation = self.media_generation
	local ok, state, err = xpcall(self.loadPreview, debug.traceback, self)
	if generation ~= self.media_generation or not self.model.active or self.released then return end
	self.media_state = ok and (state or "empty") or "failed"
	self.media_error = err
	if not ok then self.media_error = tostring(state) end
	if not ok then print("Preview: load failed: " .. self.media_error) end
end

---@return rizu.preview.PreviewLoader.State?
---@return string?
function PreviewLoader:loadPreview()
	local model = self.model
	if self.released or not model.active then return end
	local generation = self.media_generation
	local chartview = model.chartview
	local media ---@type rizu.preview.PreviewLoader.Media?
	if chartview and chartview.hash then
		media = self.probe_media(chartview)
		if generation ~= self.media_generation or chartview ~= model.chartview or not model.active then
			return
		end
		media.audio_resource_dir = get_preview_resource_dir(chartview)
	end

	local path = model.audio_path
	local preview_time = model.preview_time
	local mode = model.mode

	if not path then
		model:stop()
		return
	end

	if model.chartview and self.repaired_notes[get_notes_key(model.chartview)] then
		model.chartview.notes_preview = self.repaired_notes[get_notes_key(model.chartview)]
	end
	local notes_valid = model.chartPreview:setChartview(model.chartview --[[@as rizu.library.Chartview?]])
	model:applyPreparedMedia(media, path, preview_time, mode, chartview)
	if generation ~= self.media_generation or chartview ~= model.chartview or not model.active then return end

	if chartview and media and (not media.audio_exists or not media.bga_exists or notes_valid == false) then
		local hash = chartview.hash
		if not self.attempted_hashes[hash] then
			self:generatePreview(chartview, notes_valid == false)
		end
		if self.generating_hashes[hash] then return "loading" end
		return "failed", self.generation_errors[hash] or "Preview generation did not provide all required media"
	end
	return "ready"
end

local generatePreviewAsync = thread.async(function(chartview_data)
	---@param chartview_data rizu.preview.PreviewGenerationData
	---@return boolean
	---@return string? notes_preview
	local function generate(chartview_data)
		print("Preview: generating " .. chartview_data.hash)
		local AudioPreviewGenerator = require("rizu.preview.AudioPreviewGenerator")
		local BgaPreviewGenerator = require("rizu.preview.BgaPreviewGenerator")
		local Decoder = require("rizu.engine.audio.bass.Decoder")
		local ChartFactory = require("chart.format.notechart.ChartFactory")
		local ChartfileReader = require("rizu.library.ChartfileReader")
		local IidxDecodeContext = require("chart.format.iidx.DecodeContext")
		local LoveFilesystem = require("fs.LoveFilesystem")

		require("love.filesystem")
		local bass = require("bass")
		assert(bass.initNoSound(), "Preview: could not initialize worker BASS device")

		local fs = LoveFilesystem()
		local audio_generator = AudioPreviewGenerator(fs, Decoder.probeDuration)
		local bga_generator = BgaPreviewGenerator(fs)

		local content = ChartfileReader.read(fs, chartview_data.location_path)
		if not content then
			print("Preview: could not read " .. tostring(chartview_data.location_path))
			return false
		end
		---@type chart.iidx.DecodeContext?
		local decode_context
		if chartview_data.format == "iidx" then
			decode_context = IidxDecodeContext.fromLocation(
				fs,
				chartview_data.location_prefix,
				chartview_data.chartfile_name
			)
		end

		local chart_chartmetas, chart_error = ChartFactory:getCharts(
			chartview_data.chartfile_name,
			content,
			chartview_data.hash,
			decode_context
		)
		if not chart_chartmetas then
			print("Preview: chart parsing failed for " .. tostring(chartview_data.chartfile_name))
			return false, chart_error
		end

		local t = chart_chartmetas[chartview_data.index]
		if not t then
			print("Preview: chart index " .. tostring(chartview_data.index) .. " not found")
			return false
		end

		t.chart.layers.main:toAbsolute()

		local audio_preview_path = "userdata/audio_previews/" .. chartview_data.hash .. ".audio_preview"
		if not fs:getInfo(audio_preview_path) then
			audio_generator:generate(t.chart, chartview_data.preview_resource_dir, chartview_data.hash)
		end

		local bga_preview_path = "userdata/bga_previews/" .. chartview_data.hash .. ".bga_preview"
		if not fs:getInfo(bga_preview_path) then
			bga_generator:generate(t.chart, chartview_data.hash)
		end

		---@type string?
		local notes_preview
		if chartview_data.regenerate_notes then
			local PreviewDiffcalc = require("chart.difficulty.PreviewDiffcalc")
			local ModifierModel = require("sphere.models.ModifierModel")
			if chartview_data.modifiers then
				ModifierModel:apply(chartview_data.modifiers, t.chart)
			end
			local ctx = {chart = t.chart, chartdiff = {}}
			PreviewDiffcalc():compute(ctx)
			---@diagnostic disable-next-line: no-unknown
			notes_preview = ctx.chartdiff.notes_preview
			assert(notes_preview and notes_preview ~= "", "Preview: notes regeneration failed")
			local Sph = require("chart.format.sph.Sph")
			local SphPreview = require("chart.format.sph.SphPreview")
			local ChartDecoder = require("chart.format.sph.ChartDecoder")
			local sph = Sph()
			sph.metadata:set("title", "")
			sph.metadata:set("artist", "")
			sph.metadata:set("input", tostring(t.chart.inputMode))
			sph.sphLines:decode(SphPreview:decodeLines(notes_preview))
			ChartDecoder():decodeSph(sph)
		end

		return true, notes_preview
	end

	local ok, result, notes_preview = xpcall(generate, debug.traceback, chartview_data)
	if not ok then
		return false, tostring(result)
	end
	return result, notes_preview
end)

---@param chartview_data rizu.preview.PreviewGenerationData
function PreviewLoader:startPreviewGeneration(chartview_data)
	local hash = chartview_data.hash
	self.active_generation_hash = hash
	self.generating_hashes[hash] = true

	thread.coro(function()
		local ok, result, detail = pcall(self.generate_async or generatePreviewAsync, chartview_data)
		self.generating_hashes[hash] = nil
		self.attempted_hashes[hash] = true
		self.active_generation_hash = nil
		if ok and result then
			if detail and detail ~= "" then
				self.repaired_notes[get_notes_key(chartview_data)] = detail
				if not self.released and chartview_data.chartdiff_id and chartview_data.chartdiff_id > 0 then
					local saved, save_error = pcall(
						self.game.persistence.library.chartsRepo.repairNotesPreview,
						self.game.persistence.library.chartsRepo,
						chartview_data.chartdiff_id,
						chartview_data.previous_notes_preview,
						detail
					)
					if not saved then
						print("Preview: could not save repaired notes for " .. hash .. ": " .. tostring(save_error))
					end
				end
			end
		else
			local message = tostring(detail or result)
			print("Preview: generation failed for " .. hash .. " error: " .. message)
			self.generation_errors[hash] = message
		end

		local pending = self.pending_generation
		self.pending_generation = nil
		if pending and not self.released and self.model.active then
			self:startPreviewGeneration(pending)
		end
		-- Start pending work before the probe yields, keeping generation serialized.
		-- Re-probe current intent on success or failure, including A -> B -> A.
		if not self.released and self.model.active and self.model.chartview and self.model.chartview.hash == hash then
			self:loadPreviewSafe()
		end
	end)()
end

---@param chartview rizu.preview.PreviewChartview
---@param regenerate_notes boolean?
function PreviewLoader:generatePreview(chartview, regenerate_notes)
	local hash = chartview.hash
	if self.released or not self.model.active then return end
	if self.generating_hashes[hash] then
		return
	end

	---@type rizu.preview.PreviewGenerationData
	local chartview_data = {
		location_path = chartview.location_path,
		location_prefix = chartview.location_prefix,
		location_dir = chartview.location_dir,
		preview_resource_dir = get_preview_resource_dir(chartview),
		chartfile_name = chartview.chartfile_name,
		format = chartview.format,
		index = chartview.index,
		hash = hash,
		regenerate_notes = regenerate_notes,
		chartdiff_id = chartview.chartdiff_id,
		previous_notes_preview = chartview.notes_preview,
		modifiers = chartview.modifiers,
	}

	if self.active_generation_hash then
		local pending = self.pending_generation
		if pending then
			self.generating_hashes[pending.hash] = nil
		end
		self.pending_generation = chartview_data
		self.generating_hashes[hash] = true
		return
	end

	self:startPreviewGeneration(chartview_data)
end

---Stop media intent; in-flight work may finish but cannot activate stopped playback.
function PreviewLoader:stop()
	self.media_generation = self.media_generation + 1
	self.media_state = "empty"
	self.media_error = nil
	local pending = self.pending_generation
	if pending then self.generating_hashes[pending.hash] = nil end
	self.pending_generation = nil
end

function PreviewLoader:release()
	if self.released then return end
	self:stop()
	self.released = true
end

return PreviewLoader
