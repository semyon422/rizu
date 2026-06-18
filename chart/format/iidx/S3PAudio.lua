local S3P = require("chart.format.iidx.S3P")

---@class chart.iidx.S3PAudio
local S3PAudio = {}

---@param data string
---@return string?
---@return string? err
local function decode_audio(data)
	local ok, video = pcall(require, "video")
	if not ok then
		return nil, video
	end

	return video.decode_audio(data)
end

---@param pack chart.iidx.S3PPack
---@param sample_id integer
---@return string?
function S3PAudio.payload_by_id(pack, sample_id)
	local sample = pack.samples[sample_id]
	if sample and sample.audio_payload then
		return sample.audio_payload
	end
	local payload = S3P.sample_payload_by_id(pack, sample_id)
	if not payload then
		return nil
	end
	if sample and sample.format == "asf/wma" then
		local wav, err = decode_audio(payload)
		if not wav then
			error(("failed to decode S3P WMA sample %s: %s"):format(sample_id, tostring(err)))
		end
		sample.audio_payload = wav
		return wav
	end
	if sample then
		sample.audio_payload = payload
	end
	return payload
end

return S3PAudio
