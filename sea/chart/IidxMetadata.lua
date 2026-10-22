local types = require("sea.shared.types")

---@class sea.IidxMetadata
---@field song_id integer
---@field title string
---@field artist string?
---@field genre string?
---@field levels table<string, integer>?
local IidxMetadata = {}

---@type table<string, boolean>
local variations = {
	SPB = true, SPN = true, SPH = true, SPA = true, SPL = true,
	DPB = true, DPN = true, DPH = true, DPA = true, DPL = true,
}

---@param metadata sea.IidxMetadata
---@return boolean
function IidxMetadata.validate(metadata)
	if type(metadata) ~= "table" or not types.count(metadata.song_id)
		or not types.description(metadata.title) or metadata.title == ""
	then
		return false
	end
	for _, key in ipairs({"artist", "genre"}) do
		if metadata[key] ~= nil and not types.description(metadata[key]) then
			return false
		end
	end
	if metadata.levels ~= nil then
		if type(metadata.levels) ~= "table" then
			return false
		end
		for name, level in pairs(metadata.levels) do
			if not variations[name] or not types.count(level) or level > 255 then
				return false
			end
		end
	end
	return true
end

---@param chartmeta sea.Chartmeta?
---@return boolean
function IidxMetadata.isMissing(chartmeta)
	-- shortcut: legacy rows lack provenance; add a flag if numeric titles need unambiguous completion tracking.
	return not chartmeta or chartmeta.format == "iidx"
		and (not chartmeta.title or tonumber(chartmeta.title) ~= nil)
		and not chartmeta.artist and not chartmeta.source and not chartmeta.level
end

---@param chartmeta sea.Chartmeta
---@param metadata sea.IidxMetadata
function IidxMetadata.apply(chartmeta, metadata)
	chartmeta.title = metadata.title
	chartmeta.title_unicode = metadata.title
	chartmeta.artist = metadata.artist
	chartmeta.artist_unicode = metadata.artist
	chartmeta.source = metadata.genre
	chartmeta.level = metadata.levels and metadata.levels[chartmeta.name]
end

---@param target sea.Chartmeta
---@param source sea.Chartmeta
function IidxMetadata.preserve(target, source)
	if target.format == "iidx" and IidxMetadata.isMissing(target) and not IidxMetadata.isMissing(source) then
		target.title = source.title
		target.title_unicode = source.title_unicode
		target.artist = source.artist
		target.artist_unicode = source.artist_unicode
		target.source = source.source
		target.level = source.level
	end
end

return IidxMetadata
