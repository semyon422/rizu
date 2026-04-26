return {
	game = {
		repo = "https://dl.rizu.su",
		api = "https://rizu.su",
		multiplayer = "rizu.su:9000",
		websocket = "wss://rizu.su/ws",
	},
	osu = {
		background = "https://assets.ppy.sh/beatmaps/%s/covers/cover.jpg",
		preview = "https://b.ppy.sh/preview/%s.mp3",
		download = "https://catboy.best/d/%s",
		search = "https://catboy.best/api/v2/search",
	},
	repo = {
		name = "rizu",
		extract = {
			"bin",
			"resources",
			"game-appimage",
			"game-linux",
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
	},
}
