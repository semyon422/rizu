local class = require("class")

---@class rizu.dlc.DlcTask
---@operator call: rizu.dlc.DlcTask
---@field id string|number
---@field provider string
---@field type rizu.dlc.DlcType
---@field metadata table?
---@field status string
---@field progress number
---@field speed number
---@field total number
---@field size number
---@field error string?
local DlcTask = class()

---@param id string|number
---@param provider string
---@param _type rizu.dlc.DlcType
---@param metadata table
function DlcTask:new(id, provider, _type, metadata)
	self.id = id
	self.provider = provider
	self.type = _type
	self.metadata = metadata
	self.status = "queued"
	self.progress = 0
	self.speed = 0
	self.total = 0
	self.size = 0
	self.error = nil
end

return DlcTask
