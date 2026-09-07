local ISource = require("rizu.engine.audio.ISource")

---@class rizu.audio.fake.MixerSource: rizu.audio.ISource
---@operator call: rizu.audio.fake.MixerSource
local MixerSource = ISource + {}

---@param sample_format rizu.audio.SampleFormat?
function MixerSource:new(sample_format)
	self.active_sounds = {}
	self.sample_format = sample_format or "int16"
	self.volume = 1
	self.rate = 1
end

function MixerSource:addSound(decoder, volume)
	assert(decoder:getSampleFormat() == self.sample_format, "Decoder sample format must match MixerSource format")
	table.insert(self.active_sounds, {
		decoder = decoder,
		volume = volume or 1,
	})
end

function MixerSource:setVolume(vol) self.volume = vol end
function MixerSource:setRate(rate) self.rate = rate end
function MixerSource:update()
	for _, sound in ipairs(self.active_sounds) do
		sound.decoder:release()
	end
	self.active_sounds = {}
end
function MixerSource:play() end
function MixerSource:pause() end

return MixerSource
