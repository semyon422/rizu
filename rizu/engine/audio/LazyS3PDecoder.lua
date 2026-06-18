local LazyDecoder = require("rizu.engine.audio.LazyDecoder")
local S3PAudio = require("chart.format.iidx.S3PAudio")

---@class rizu.audio.LazyS3PDecoder: rizu.audio.LazyDecoder
---@operator call: rizu.audio.LazyS3PDecoder
---@field private pack chart.iidx.S3PPack
---@field private sample_id integer
local LazyS3PDecoder = LazyDecoder + {}

---@param pack chart.iidx.S3PPack
---@param sample_id integer
---@param factory fun(data: string): rizu.audio.IDecoder
---@param duration number
---@param sample_rate integer
---@param channels integer
---@param bytes_per_sample integer
---@param volume number?
function LazyS3PDecoder:new(pack, sample_id, factory, duration, sample_rate, channels, bytes_per_sample, volume)
	self:init(factory, duration, sample_rate, channels, bytes_per_sample, volume)
	self.pack = pack
	self.sample_id = sample_id
end

---@return string
function LazyS3PDecoder:loadData()
	return assert(S3PAudio.payload_by_id(self.pack, self.sample_id), "missing S3P sample")
end

return LazyS3PDecoder
