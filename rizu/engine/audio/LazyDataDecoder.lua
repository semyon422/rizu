local LazyDecoder = require("rizu.engine.audio.LazyDecoder")

---@class rizu.audio.LazyDataDecoder: rizu.audio.LazyDecoder
---@operator call: rizu.audio.LazyDataDecoder
---@field private data string
local LazyDataDecoder = LazyDecoder + {}

---@param data string
---@param factory fun(data: string): rizu.audio.IDecoder
---@param duration number
---@param sample_rate integer
---@param channels integer
---@param sample_format rizu.audio.SampleFormat
---@param volume number?
function LazyDataDecoder:new(data, factory, duration, sample_rate, channels, sample_format, volume)
	self:init(factory, duration, sample_rate, channels, sample_format, volume)
	self.data = data
end

function LazyDataDecoder:loadData()
	return self.data
end

return LazyDataDecoder
