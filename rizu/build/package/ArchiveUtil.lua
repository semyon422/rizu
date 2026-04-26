local ArchiveUtil = {}

---@param listing string?
---@param path string
---@return boolean
function ArchiveUtil.hasEntry(listing, path)
	return listing ~= nil and listing:find(path, 1, true) ~= nil
end

---@param ctx rizu.build.Context
---@param zip_path string
---@return string
function ArchiveUtil.getZipListing(ctx, zip_path)
	local listing = ctx.shell:popen(string.format("unzip -l %q", zip_path))
	assert(listing and #listing > 0, "failed to read archive listing: " .. zip_path)
	return listing
end

return ArchiveUtil
