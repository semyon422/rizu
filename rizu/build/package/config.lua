---@class rizu.build.package.Config
---@field game {repo: string, servers: sphere.ServerConfig[]}
---@field repo {name: string, extract: string[], include: string[], runtime_assets: string[]}

---@type {repo_url: string, servers: sphere.ServerConfig[]?}
local endpoints = require("server-state.package_config")

assert(type(endpoints.repo_url) == "string" and endpoints.repo_url ~= "", "package repo_url is required")
assert(type(endpoints.servers) == "table" and #endpoints.servers > 0, "package servers are required")
for _, server in ipairs(endpoints.servers) do
	assert(type(server.name) == "string" and server.name ~= "", "package server name is required")
	assert(type(server.url) == "string" and server.url ~= "", "package server URL is required")
end

---@type rizu.build.package.Config
return {
	game = {
		repo = endpoints.repo_url,
		servers = endpoints.servers,
	},
	repo = {
		name = "rizu",
		extract = {
			"bin",
			"resources",
			"game-appimage",
			"game-macos",
			"game-win64.bat",
		},
		include = {
			"rizu",
			"sphere",
			"sea",
			"aqua",
			"chart",
			"gui",
			"native",
			"ui",
		},
		runtime_assets = {
			"rizu/ai/SystemPrompt.md",
		},
	},
}
