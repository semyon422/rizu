local class = require("class")

---@alias chart.ResourceType "sound"|"image"|"ojm"|"s3p"|"2dx"

---@class chart.Resources
---@operator call: chart.Resources
local Resources = class()

---@param _type chart.ResourceType
---@param name string
---@param ... string fallbacks
function Resources:add(_type, name, ...)
	self[_type] = self[_type] or {}
	self[_type][name] = {name, ...}
end

---@return fun(): chart.ResourceType, string[]
function Resources:iter()
	return coroutine.wrap(function()
		for _type, data in pairs(self) do
			for name, paths in pairs(data) do
				coroutine.yield(_type, paths)
			end
		end
	end)
end

return Resources
