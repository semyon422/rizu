---@class sea.AppConfig
---@field compute {host: string, port: integer, timeout: number, max_payload_size: integer}
local AppConfig = {
	sessions_secret = "secret",

	is_register_enabled = true,
	is_login_enabled = true,
	is_register_captcha_enabled = false,
	is_login_captcha_enabled = false,
	recaptcha = {
		site_key = "",
		secret_key = "",
		required_score = 0.5,
	},

	osu_api = {
		client_id = 0,
		client_secret = "",
		redirect_uri = "",
	},

	compute = {
		host = "127.0.0.1",
		port = 8191,
		timeout = 120,
		max_payload_size = 64 * 1024 * 1024,
	},

	responsible_person = {
		name = "Name",
		email = "email@example.com",
	},
}

return AppConfig
