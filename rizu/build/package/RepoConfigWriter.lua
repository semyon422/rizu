local class = require("class")
local stbl = require("stbl")
local json = require("json")
local config = require("rizu.build.package.config")

---@class rizu.build.package.RepoConfigWriter
---@operator call: rizu.build.package.RepoConfigWriter
---@field ctx rizu.build.Context
local RepoConfigWriter = class()

---@param ctx rizu.build.Context
function RepoConfigWriter:new(ctx)
	self.ctx = ctx
end

---@param t table
---@return string
local function serialize(t)
	return ("return %s\n"):format(stbl.encode(t))
end

---@param gamedir string
function RepoConfigWriter:write(gamedir)
	local format = '{"commit":"%H","date":"%cd"}'
	local res = self.ctx.shell:popen("git log -1 --format='" .. format .. "'")
	local version = {
		date = "unknown",
		commit = "unknown",
	}

	if res then
		local ok, data = pcall(json.decode, res)
		if ok and type(data) == "table" then
			version.date = data.date or "unknown"
			version.commit = data.commit or "unknown"
		end
	end

	self.ctx.fs:write(gamedir .. "/version.lua", serialize(version))

	local urls_path = gamedir .. "/sphere/persistence/ConfigModel/urls.lua"
	local content = self.ctx.fs:read(urls_path)
	if content then
		---@type (fun(): sphere.UrlsConfig)?
		local chunk = loadstring(content)
		if chunk then
			local urls = chunk()
			urls.websocket = config.game.websocket
			urls.update = config.game.repo .. "/files.json"
			self.ctx.fs:write(urls_path, serialize(urls))
		end
	end
end

return RepoConfigWriter
