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
---@return yi.command_palette.Command[]
return function(game)
	return {
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
