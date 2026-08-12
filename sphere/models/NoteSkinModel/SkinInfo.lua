local class = require("class")

---@class sphere.SkinInfo
---@operator call: sphere.SkinInfo
---@field name string
---@field dir string
---@field file_name string
local SkinInfo = class()

---@param inputMode string
---@return boolean
function SkinInfo:matchInput(inputMode)
	return true
end

---@return string
function SkinInfo:getPath()
	return self.dir .. "/" .. self.file_name
end

return SkinInfo
