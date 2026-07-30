local config = {
	listen = 8180,
	lua_code_cache = "on",
	client_max_body_size = "10M",
	handler = "sea.app.handler",
	proxied = true,
	package_path = {
		"libchart",
		"3rd-deps/lua",
		"ncdk",
		"chartbase",
	},
	package_cpath = {},
	require = {
		"socket",
		"ltn12",
		"mime",
		"utf8",
	},
	shared_dicts = {
		players = "1m",
		mp_rooms = "1m",
		mp_room_users = "1m",
		bancho_players = "10m",
		bancho_matches = "5m",
		bancho_channels = "1m",
	},
}

return config

