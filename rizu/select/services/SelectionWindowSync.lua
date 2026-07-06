local class = require("class")

---@class rizu.select.ISelectionWindowSync
---@field update fun(self: rizu.select.ISelectionWindowSync)

---@class rizu.select.services.SelectionWindowSync: rizu.select.ISelectionWindowSync
---@operator call: rizu.select.services.SelectionWindowSync
local SelectionWindowSync = class()

---@param windowModel rizu.WindowModel
function SelectionWindowSync:new(windowModel)
	self.windowModel = windowModel
end

function SelectionWindowSync:update()
	self.windowModel:setVsyncOnSelect(true)
end

return SelectionWindowSync
