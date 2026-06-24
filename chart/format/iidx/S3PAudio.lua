local S3P = require("chart.format.iidx.S3P")

---@class chart.iidx.S3PAudio
local S3PAudio = {}

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
	if sample then
		sample.audio_payload = payload
	end
	return payload
end

return S3PAudio
