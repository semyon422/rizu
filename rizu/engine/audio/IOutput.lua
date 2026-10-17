local class = require("class")

---@class rizu.audio.IOutput
---@operator call: rizu.audio.IOutput
local IOutput = class()

function IOutput:release() end
function IOutput:play() end
function IOutput:pause() end
function IOutput:update() end
function IOutput:clear() end

---@param decoded_position number
---@return number audible_position
function IOutput:getPosition(decoded_position)
	return decoded_position
end

return IOutput
