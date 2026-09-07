local IProvider = require("rizu.engine.audio.IProvider")
local Decoder = require("rizu.engine.audio.bass.Decoder")
local Source = require("rizu.engine.audio.bass.Source")
local MixerSource = require("rizu.engine.audio.bass.MixerSource")

---@class rizu.audio.bass.Provider: rizu.audio.IProvider
---@operator call: rizu.audio.bass.Provider
local Provider = IProvider + {}

function Provider:createDecoder(data, float_output)
	return Decoder(data, float_output)
end

function Provider:createChartSource(decoder, use_tempo)
	return Source(decoder, use_tempo)
end

function Provider:createMixerSource(use_tempo, float_output)
	return MixerSource(use_tempo, float_output)
end

return Provider
