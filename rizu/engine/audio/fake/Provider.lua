local IProvider = require("rizu.engine.audio.IProvider")
local Decoder = require("rizu.engine.audio.fake.Decoder")
local Source = require("rizu.engine.audio.fake.Source")
local MixerSource = require("rizu.engine.audio.fake.MixerSource")

---@class rizu.audio.fake.Provider: rizu.audio.IProvider
---@operator call: rizu.audio.fake.Provider
local Provider = IProvider + {}

function Provider:createDecoder(data, sample_format)
	-- Use a small amount of samples as placeholder if data is a string
	local count = type(data) == "string" and #data or 100
	return Decoder(count, nil, nil, sample_format)
end

function Provider:createChartSource(decoder, use_tempo)
	return Source(decoder)
end

function Provider:createMixerSource(use_tempo, sample_format)
	return MixerSource(sample_format)
end

return Provider
