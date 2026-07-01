local class = require("class")

---@class rizu.select.services.SelectionWindowSync
---@operator call: rizu.select.services.SelectionWindowSync
local SelectionWindowSync = class()

---@param windowModel sphere.WindowModel
function SelectionWindowSync:new(windowModel)
	self.windowModel = windowModel
end

function SelectionWindowSync:update()
	self.windowModel:setVsyncOnSelect(true)
end

return SelectionWindowSync
