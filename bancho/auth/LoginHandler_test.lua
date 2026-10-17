--- Tests for bancho auth LoginHandler.

local LoginHandler = require("bancho.auth.LoginHandler")

local test = {}

function test.login_parse_basic(t)
	local body = "TestUser\ntest_password_md5\nb20240101r1stable|5|0|abc123:adapter.string.:adapters_md5:uninstall_md5:disk_sig|0\n"
	local result = LoginHandler.parse(body)

	t:eq(result.ok, true)
	t:eq(result.data.username, "TestUser")
	t:eq(result.data.password_md5, "test_password_md5")
	t:eq(result.data.utc_offset, 5)
	t:eq(result.data.display_city, false)
	t:eq(result.data.pm_private, false)
end

function test.login_parse_display_city(t)
	local body = "User\npass\nb20240101r1stable|0|1|hashes|1\n"
	local result = LoginHandler.parse(body)
	t:eq(result.data.display_city, true)
	t:eq(result.data.pm_private, true)
end

function test.login_parse_invalid_body(t)
	local result = LoginHandler.parse("only_one_line\n")
	t:eq(result.ok, false)
	t:eq(result.failure_reason, -5)
end

function test.login_parse_empty_username(t)
	local result = LoginHandler.parse("\npass\nb20240101r1stable|0|0|hash|0\n")
	t:eq(result.ok, false)
end

function test.login_parse_empty_password(t)
	local result = LoginHandler.parse("user\n\nb20240101r1stable|0|0|hash|0\n")
	t:eq(result.ok, false)
end

function test.login_parse_9_parts(t)
	-- The remainder has 5 pipe-delimited parts
	local body = "u\np\nb20240101r1stable|0|0|hash:val:val:val:val|0\n"
	local result = LoginHandler.parse(body)
	t:eq(result.ok, true)
end

function test.validate_empty_adapters(t)
	local handler = LoginHandler()
	local login_data = {client_hashes = {adapters_str = ""}}
	t:eq(handler:validate(login_data), false)
end

function test.validate_valid_adapters(t)
	local handler = LoginHandler()
	local login_data = {client_hashes = {adapters_str = "adapter.string"}}
	t:eq(handler:validate(login_data), true)
end

function test.client_hashes_parse(t)
	local body = "user\npass\nb20240101r1stable|0|0|hash1:hash2:hash3:hash4:hash5|0\n"
	local result = LoginHandler.parse(body)
	t:eq(result.data.client_hashes.osupath_md5, "hash1")
	t:eq(result.data.client_hashes.adapters_str, "hash2")
	t:eq(result.data.client_hashes.adapters_md5, "hash3")
	t:eq(result.data.client_hashes.uninstall_md5, "hash4")
	t:eq(result.data.client_hashes.disk_signature_md5, "hash5")
end

return test
