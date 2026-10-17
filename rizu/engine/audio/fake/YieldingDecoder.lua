local IDecoder = require("rizu.engine.audio.IDecoder")

---@class rizu.audio.fake.YieldingDecoder: rizu.audio.IDecoder
---@operator call: rizu.audio.fake.YieldingDecoder
---@field private decoder rizu.audio.IDecoder
local YieldingDecoder = IDecoder + {}

---@param decoder rizu.audio.IDecoder
function YieldingDecoder:new(decoder)
	self.decoder = decoder
end

function YieldingDecoder:getFrames(...)
	coroutine.yield()
	return self.decoder:getFrames(...)
end

function YieldingDecoder:getFramePosition(...)
	coroutine.yield()
	return self.decoder:getFramePosition(...)
end

function YieldingDecoder:setFramePosition(...)
	coroutine.yield()
	return self.decoder:setFramePosition(...)
end

function YieldingDecoder:getFrameDuration(...)
	coroutine.yield()
	return self.decoder:getFrameDuration(...)
end

function YieldingDecoder:getSampleRate(...)
	coroutine.yield()
	return self.decoder:getSampleRate(...)
end

function YieldingDecoder:getChannelCount(...)
	coroutine.yield()
	return self.decoder:getChannelCount(...)
end

function YieldingDecoder:getSampleFormat(...)
	coroutine.yield()
	return self.decoder:getSampleFormat(...)
end

function YieldingDecoder:release()
	coroutine.yield()
	self.decoder:release()
end

return YieldingDecoder
