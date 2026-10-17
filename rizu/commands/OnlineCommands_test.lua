local OnlineCommands = require("rizu.commands.OnlineCommands")

local test = {}

local function getSwitchCommand()
	local game = {
		persistence = {
			configModel = {
				configs = {
					online = {url = "wss://primary.example/ws"},
					urls = {servers = {
						{name = "Primary", url = "wss://primary.example/ws"},
						{name = "Community", url = "wss://community.example/ws"},
					}},
				},
			},
		},
	}
	local commands = OnlineCommands(game --[[@as sphere.GameController]])
	return commands[1], game
end

---@param t testing.T
function test.switch_server_lists_packaged_servers(t)
	local command = getSwitchCommand()
	local choices = command.arguments[1].choices()

	t:tdeq(choices, {
		{title = "Primary", value = "wss://primary.example/ws"},
		{title = "Community", value = "wss://community.example/ws"},
	})
end

---@param t testing.T
function test.switch_server_persists_online_selection_and_restarts(t)
	local command, game = getSwitchCommand()
	local written
	function game.persistence.configModel:write(name)
		written = name
	end

	local quit_arg
	local old_love = love
	love = {event = {quit = function(arg) quit_arg = arg end}}
	local ok, err = pcall(command.callback, {url = "wss://community.example/ws"})
	love = old_love
	if not ok then
		error(err, 0)
	end

	t:eq(game.persistence.configModel.configs.online.url, "wss://community.example/ws")
	t:eq(written, "online")
	t:eq(quit_arg, "restart")
end

return test
