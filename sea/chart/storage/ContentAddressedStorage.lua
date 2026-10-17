local digest = require("digest")
local IKeyValueStorage = require("sea.chart.storage.IKeyValueStorage")

---@class sea.ContentAddressedStorage: sea.IKeyValueStorage
---@operator call: sea.ContentAddressedStorage
local ContentAddressedStorage = IKeyValueStorage + {}

---@param storage sea.IKeyValueStorage
function ContentAddressedStorage:new(storage)
	self.storage = storage
end

---@param key string
---@return string?
---@return string?
function ContentAddressedStorage:get(key)
	return self.storage:get(key)
end

---@param key string
---@param value string
---@return true?
---@return string?
function ContentAddressedStorage:set(key, value)
	if digest.hash("md5", value, true) ~= key then
		return nil, "content hash mismatch"
	end

	local stored = self.storage:get(key)
	if stored then
		if stored ~= value then
			return nil, "stored content mismatch"
		end
		return true
	end

	return self.storage:set(key, value)
end

return ContentAddressedStorage
