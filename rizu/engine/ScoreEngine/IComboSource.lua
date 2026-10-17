local class = require("class")

---@class rizu.IComboSource
---@operator call: rizu.IComboSource
local IComboSource = class()

---@return integer
function IComboSource:getCombo()
	error("not implemented")
end

---@return integer
function IComboSource:getMaxCombo()
	error("not implemented")
end

return IComboSource
