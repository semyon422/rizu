local class = require("class")
local path_util = require("path_util")
local decibel = require("decibel")
local Wave = require("audio.Wave")

---@class rizu.editor.exports.BmsKeysoundSlicer
---@operator call: rizu.editor.exports.BmsKeysoundSlicer
local BmsKeysoundSlicer = class()

function BmsKeysoundSlicer:slice(chartSelector, editorModel)
	local chartview = chartSelector.chartview
	local real_dir = chartview.real_dir

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

	local dir = path_util.join(real_dir, chartview.name)
	assert(love.filesystem.createDirectory(dir))

	---@type chartedit.Notes
	local notes = editorModel.notes
	local linkedNotes = notes:getLinkedNotes()

	local sample_rate = wave_full.sample_rate
	local channels_count = wave_full.channels_count

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

			note.data.sounds = {{path_util.join(chartview.name, file_name), 1}}

			local path = path_util.join(dir, file_name)
			love.filesystem.write(path, wave:encode())
			ks_index = ks_index + 1
		end
	end
end

return BmsKeysoundSlicer
