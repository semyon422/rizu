local class = require("class")
local stbl = require("stbl")
local config = require("rizu.build.package.config")

---@class rizu.build.package.RepoConfigWriter
---@operator call: rizu.build.package.RepoConfigWriter
---@field ctx rizu.build.Context
---@field git_repo rizu.build.package.CurrentRepo
local RepoConfigWriter = class()

---@param ctx rizu.build.Context
---@param git_repo rizu.build.package.CurrentRepo
function RepoConfigWriter:new(ctx, git_repo)
	self.ctx = ctx
	self.git_repo = git_repo
end

local function serialize(t)
	return ("return %s\n"):format(stbl.encode(t))
end

---@param gamedir string
function RepoConfigWriter:write(gamedir)
	self.ctx.fs:write(gamedir .. "/version.lua", serialize({
		date = self.git_repo:log_date(),
		commit = self.git_repo:log_commit(),
	}))

	local urls_path = gamedir .. "/sphere/persistence/ConfigModel/urls.lua"
	local content = self.ctx.fs:read(urls_path)
	if content then
		local chunk = loadstring(content)
		if chunk then
			local urls = chunk()
			urls.host = config.game.api
			urls.websocket = config.game.websocket
			urls.update = config.game.repo .. "/files.json"
			urls.osu = config.osu
			urls.multiplayer = config.game.multiplayer
			self.ctx.fs:write(urls_path, serialize(urls))
		end
	end
end

return RepoConfigWriter
