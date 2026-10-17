local IProvider = require("rizu.engine.audio.IProvider")
local Decoder = require("rizu.engine.audio.bass.Decoder")
local Source = require("rizu.engine.audio.bass.Source")
local MixerSource = require("rizu.engine.audio.bass.MixerSource")
local Output = require("rizu.engine.audio.sdl.Output")
local OutputConfig = require("rizu.engine.audio.OutputConfig")

---@class rizu.audio.bass.Provider: rizu.audio.IProvider
---@operator call: rizu.audio.bass.Provider
local Provider = IProvider + {}

---@param decode_output boolean?
function Provider:new(decode_output)
	self.decode_output = decode_output == true
end

function Provider:createDecoder(data, sample_format)
	return Decoder(data, sample_format)
end

function Provider:createChartSource(decoder, use_tempo)
	return Source(decoder, use_tempo, self.decode_output)
end

function Provider:createMixerSource(use_tempo, sample_format)
	return MixerSource(use_tempo, sample_format, self.decode_output)
end

function Provider:createOutput(sources)
	if not self.decode_output then
		return IProvider.createOutput(self, sources)
	end
	return Output(sources, OutputConfig.get())
end

return Provider
