local class = require("class")

---@class rizu.audio.IProvider
---@operator call: rizu.audio.IProvider
local IProvider = class()

---@param data string
---@param float_output boolean?
---@return rizu.audio.IDecoder
function IProvider:createDecoder(data, float_output)
	error("not implemented")
end

---@param decoder rizu.audio.IDecoder
---@param use_tempo boolean?
---@return rizu.audio.ISource
function IProvider:createChartSource(decoder, use_tempo)
	error("not implemented")
end

---@param use_tempo boolean?
---@param float_output boolean?
---@return rizu.audio.ISource
function IProvider:createMixerSource(use_tempo, float_output)
	error("not implemented")
end

return IProvider
