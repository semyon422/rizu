local class = require("class")
local valid = require("valid")
local types = require("sea.shared.types")
local IidxMetadata = require("sea.chart.IidxMetadata")

---@class sea.ComputeDataProviderRemoteValidation: sea.ComputeDataProvider
---@operator call: sea.ComputeDataProviderRemoteValidation
local ComputeDataProviderRemoteValidation = class()

---@param compute_data_provider sea.IComputeDataProvider
function ComputeDataProviderRemoteValidation:new(compute_data_provider)
	self.compute_data_provider = compute_data_provider
end

local validate_chart = valid.wrap_format(valid.struct({
	name = types.string,
	data = types.binary,
}))

---@param hash string
---@return {name: string, data: string}?
---@return string?
function ComputeDataProviderRemoteValidation:getChartData(hash)
	assert(types.md5hash(hash))

	local t, err = self.compute_data_provider:getChartData(hash)
	if not t then
		assert(type(t) == "nil")
		assert(types.string(err))
		return nil, err
	end

	assert(validate_chart(t))

	return t
end

---@param hash string
---@return sea.IidxMetadata?
---@return string?
function ComputeDataProviderRemoteValidation:getIidxMetadata(hash)
	assert(types.md5hash(hash))
	local metadata, err = self.compute_data_provider:getIidxMetadata(hash)
	if not metadata then
		return nil, err
	end
	if not IidxMetadata.validate(metadata) then
		return nil, "invalid IIDX metadata"
	end
	return metadata
end

---@param replay_hash string
---@return string?
---@return string?
function ComputeDataProviderRemoteValidation:getReplayData(replay_hash)
	assert(types.md5hash(replay_hash))

	local data, err = self.compute_data_provider:getReplayData(replay_hash)
	if not data then
		assert(type(data) == "nil")
		assert(types.string(err))
		return nil, err
	end

	assert(types.binary(data))

	return data
end

return ComputeDataProviderRemoteValidation
