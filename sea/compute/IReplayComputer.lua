local class = require("class")

---@class sea.IReplayComputer
---@operator call: sea.IReplayComputer
local IReplayComputer = class()

---@param request sea.ComputeRequest
---@return sea.ComputeResult?
---@return string?
function IReplayComputer:compute(request)
	error("not implemented")
end

return IReplayComputer
