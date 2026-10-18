local FakeFilesystem = require("fs.FakeFilesystem")
local RepoConfigWriter = require("rizu.build.package.RepoConfigWriter")
local config = require("rizu.build.package.config")

local test = {}

---@param t testing.T
function test.writes_packaged_servers_to_urls_config(t)
	local fs = FakeFilesystem()
	fs:createDirectory("game/sphere/persistence/ConfigModel")
	fs:write("game/sphere/persistence/ConfigModel/urls.lua", [[
		return {
			update = "",
			servers = {{name = "Development", url = "ws://localhost:8180/ws"}},
		}
	]])
	fs:write("game/sphere/persistence/ConfigModel/online.lua", [[
		return {
			url = "ws://localhost:8180/ws",
			tokens = {},
		}
	]])
	local shell = {
		popen = function()
			return [[{"commit":"abc","date":"today"}]]
		end,
	}

	RepoConfigWriter({fs = fs, shell = shell} --[[@as rizu.build.Context]]):write("game")

	local content = assert(fs:read("game/sphere/persistence/ConfigModel/urls.lua"))
	local chunk = assert(loadstring(content))
	local urls = chunk()
	t:eq(urls.update, config.game.repo .. "/files.json")
	t:tdeq(urls.servers, config.game.servers)
	t:eq(urls.websocket, nil)

	content = assert(fs:read("game/sphere/persistence/ConfigModel/online.lua"))
	chunk = assert(loadstring(content))
	local online = chunk()
	t:eq(online.url, config.game.servers[1].url)
	t:tdeq(online.tokens, {})
end

return test
