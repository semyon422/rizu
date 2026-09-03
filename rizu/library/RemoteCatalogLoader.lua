local class = require("class")
local sqlite = require("ljsqlite3")
local zlib = require("zlib")

---@class rizu.library.RemoteCatalogItem
---@field id string
---@field title string
---@field artist string
---@field name string
---@field creator string
---@field mode integer
---@field keys integer?
---@field difficulty number
---@field format string
---@field background_url string?
---@field preview_audio_url string

---@class rizu.library.RemoteCatalogLoader
---@operator call: rizu.library.RemoteCatalogLoader
---@field network rizu.NetworkService
---@field fs fs.IFilesystem
---@field url string
---@field path string
local RemoteCatalogLoader = class()

RemoteCatalogLoader.schema_version = 11

---@param network rizu.NetworkService
---@param fs fs.IFilesystem
---@param url string?
---@param path string?
function RemoteCatalogLoader:new(network, fs, url, path)
	self.network = assert(network, "network is required")
	self.fs = assert(fs, "filesystem is required")
	self.url = url or "https://s3.kuudere.fun/catalog.sqlite"
	self.path = path or "userdata/remote_catalog/catalog.sqlite"
end

---@param encoding string?
---@param body string
---@return string
function RemoteCatalogLoader.decodeBody(encoding, body)
	if encoding and encoding:lower():find("gzip", 1, true) then
		return zlib.gunzip(body)
	end
	return body
end

---@param catalog_url string
---@param path string?
---@return string?
function RemoteCatalogLoader.assetUrl(catalog_url, path)
	if not path or path == "" then
		return nil
	end
	local base = catalog_url:match("^(.*)/[^/]*$") or catalog_url
	return base .. "/" .. path:gsub("^/", "")
end

---@param on_status fun(status: table)?
---@return rizu.library.RemoteCatalogItem[]?
---@return string?
function RemoteCatalogLoader:download(on_status)
	local res, err = self.network:download(self.url, {
		chunk_size = 64 * 1024,
		on_status = on_status,
	})
	if not res then
		return nil, err or "download failed"
	end
	if res.status >= 400 then
		return nil, "HTTP " .. res.status
	end

	local ok, body = pcall(self.decodeBody, res.headers:get("Content-Encoding"), res.body)
	if not ok then
		return nil, "could not decompress catalog: " .. tostring(body)
	end

	local directory = self.path:match("^(.*)/[^/]+$")
	if directory then
		local created, create_err = self.fs:createDirectory(directory)
		if not created then
			return nil, create_err or "could not create catalog directory"
		end
	end
	local written, write_err = self.fs:write(self.path, body)
	if not written then
		return nil, write_err or "could not write catalog"
	end

	return self:load()
end

---@return rizu.library.RemoteCatalogItem[]?
---@return string?
function RemoteCatalogLoader:load()
	local db
	local ok, result = pcall(function()
		db = sqlite.open(self.path, "ro")
		local version = db:rowexec("PRAGMA user_version")
		if version ~= self.schema_version then
			error(("incompatible catalog schema %s; expected %d"):format(tostring(version), self.schema_version))
		end

		local items = {}
		local statement = db:prepare([[
			SELECT charts.id, songs.title, songs.artist, charts.name, charts.creator,
				charts.mode, charts.keys, charts.difficulty, charts.format,
				charts.background_preview_path, charts.audio_preview_path
			FROM charts
			JOIN songs ON songs.id = charts.song_id
			ORDER BY songs.title COLLATE NOCASE, songs.artist COLLATE NOCASE,
				charts.difficulty, charts.name COLLATE NOCASE
		]])
		local row, columns = {}, {}
		while true do
			row = statement:step(row, columns)
			if not row then
				break
			end
			items[#items + 1] = {
				id = tostring(row[1]),
				title = tostring(row[2]),
				artist = tostring(row[3]),
				name = tostring(row[4]),
				creator = tostring(row[5]),
				mode = tonumber(row[6]) or 0,
				keys = tonumber(row[7]),
				difficulty = tonumber(row[8]) or 0,
				format = tostring(row[9]),
				background_url = self.assetUrl(self.url, row[10]),
				preview_audio_url = assert(self.assetUrl(self.url, row[11])),
			}
		end
		statement:close()
		return items
	end)
	if db then
		db:close()
	end
	if not ok then
		return nil, tostring(result)
	end
	return result
end

return RemoteCatalogLoader
