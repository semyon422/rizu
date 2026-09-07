local class = require("class")

---@class rizu.audio.IProvider
---@operator call: rizu.audio.IProvider
local IProvider = class()

---@param data string
---@param sample_format rizu.audio.SampleFormat?
---@return rizu.audio.IDecoder
function IProvider:createDecoder(data, sample_format)
	error("not implemented")
end

---@param decoder rizu.audio.IDecoder
---@param use_tempo boolean?
---@return rizu.audio.ISource
function IProvider:createChartSource(decoder, use_tempo)
	error("not implemented")
end

---@param use_tempo boolean?
---@param sample_format rizu.audio.SampleFormat?
---@return rizu.audio.ISource
function IProvider:createMixerSource(use_tempo, sample_format)
	error("not implemented")
end

return IProvider
