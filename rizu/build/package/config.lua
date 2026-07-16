return {
	game = {
		repo = "https://dl.rizu.su",
		websocket = "wss://rizu.su/ws",
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
			"chartbase",
			"ncdk",
			"libchart",
			"native",
			"preload",
			"ui",
			"yi",
		},
		runtime_assets = {
			"rizu/ai/SystemPrompt.md",
		},
	},
}
