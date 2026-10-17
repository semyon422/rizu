local ISource = require("rizu.engine.audio.ISource")

---@class rizu.audio.fake.Source: rizu.audio.ISource
---@operator call: rizu.audio.fake.Source
local Source = ISource + {}

function Source:new(decoder)
	self.decoder = decoder
	self.position = decoder and decoder:getPosition() or 0
	self.playing = false
	self.rate = 1
	self.volume = 1
end

function Source:play() self.playing = true end
function Source:pause() self.playing = false end
function Source:isPlaying() return self.playing end
function Source:getPosition() return self.position end
function Source:setPosition(pos) self.position = pos end
function Source:setRate(rate) self.rate = rate end
function Source:setVolume(vol) self.volume = vol end
function Source:update()
	if self.playing then
		self.position = self.position + 0.016 * self.rate
	end
end

return Source
