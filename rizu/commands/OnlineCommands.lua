---@param value string
---@return boolean valid
---@return string? error_msg
local function validateNotEmpty(value)
	if value == "" then
		return false, "Value cannot be empty"
	end
	return true
end

---@param game sphere.GameController
---@return rizu.command.Fuzzy.Candidate[] choices
local function getServerChoices(game)
	---@type rizu.command.Fuzzy.Candidate[]
	local choices = {}
	for _, server in ipairs(game.persistence.configModel.configs.urls.servers) do
		table.insert(choices, {
			title = server.name,
			value = server.url,
		})
	end
	return choices
end

---@param game sphere.GameController
---@return rizu.command.Command[]
return function(game)
	return {
		{
			id = "online.switch_server",
			title = "Online: Switch Server",
			description = "Changes the online server and restarts the game",
			arguments = {
				{
					name = "url",
					type = "string",
					prompt = "Select server:",
					choices = function()
						return getServerChoices(game)
					end,
				},
			},
			callback = function(args)
				game.persistence.configModel.configs.online.url = args.url
				game.persistence.configModel:write("online")
				love.event.quit("restart")
			end,
		},
		{
			id = "online.login",
			title = "Online: Login",
			description = "Logs in with email and password",
			arguments = {
				{
					name = "email",
					type = "string",
					prompt = "Email:",
					validate = validateNotEmpty,
				},
				{
					name = "password",
					type = "string",
					prompt = "Password:",
					validate = validateNotEmpty,
				},
			},
			callback = function(args)
				game.onlineModel.authManager:login(args.email, args.password)
			end,
		},
		{
			id = "online.quick_login",
			title = "Online: Quick Login",
			description = "Starts browser-based quick login",
			callback = function()
				game.onlineModel.authManager:quickLogin()
			end,
		},
		{
			id = "online.logout",
			title = "Online: Logout",
			description = "Logs out of the current online session",
			callback = function()
				game.onlineModel.authManager:logout()
			end,
		},
	}
end
