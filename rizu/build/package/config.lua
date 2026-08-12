---@class rizu.build.package.Config
---@field game {repo: string, websocket: string}
---@field repo {name: string, extract: string[], include: string[], runtime_assets: string[]}

---@type {repo_url: string, websocket_url: string}
local endpoints = require("server-state.package_config")

assert(type(endpoints.repo_url) == "string" and endpoints.repo_url ~= "", "package repo_url is required")
assert(type(endpoints.websocket_url) == "string" and endpoints.websocket_url ~= "", "package websocket_url is required")

---@type rizu.build.package.Config
return {
	game = {
		repo = endpoints.repo_url,
		websocket = endpoints.websocket_url,
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
