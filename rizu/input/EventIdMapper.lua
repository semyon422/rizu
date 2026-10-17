local class = require("class")

---@class rizu.EventIdMapper
---@operator call: rizu.EventIdMapper
local EventIdMapper = class()

function EventIdMapper:new()
	---@type {[any]: integer}
	self.map = {}
	---@type {[integer]: any}
	self.inv_map = {}
end

---@param id any
---@return integer
function EventIdMapper:get(id)
	local map = self.map
	local _id = map[id]
	if _id then
		return _id
	end

	local inv_map = self.inv_map

	_id = 1
	while inv_map[_id] do
		_id = _id + 1
	end

	inv_map[_id] = id
	map[id] = _id

	return _id
end

---@param id any
function EventIdMapper:free(id)
	local map = self.map
	local _id = map[id]
	if not _id then
		return
	end

	self.inv_map[_id] = nil
	map[id] = nil
end

return EventIdMapper
