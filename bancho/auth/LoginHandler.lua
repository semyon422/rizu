--- Login handler for osu! authentication flow.
---
--- Parses the login request body and validates credentials.
--- The client sends: username\npassword_md5\nosu_version|utc_offset|display_city|client_hashes|pm_private\n

local regexes = {
	OSU_VERSION = "^b(%d%d%d%d)(%d%d)(%d%d)(%d?)%.(%d?)(%S*)$",
}

local class = require("class")

---@class bancho.auth.LoginData
---@field username string
---@field password_md5 string
---@field osu_version string
---@field utc_offset integer
---@field display_city boolean
---@field client_hashes string
---@field pm_private boolean

--- Parse the client hashes portion.
--- Format: "path_md5:adapters_str:adapters_md5:uninstall_md5:disk_signature_md5"
---@param client_hashes string
---@return {osupath_md5: string, adapters_str: string, adapters_md5: string, uninstall_md5: string, disk_signature_md5: string}
local function parseClientHashes(client_hashes)
	-- Remove trailing colon
	client_hashes = client_hashes:gsub(":%s*$", "")
	---@type string[]
	local parts = {}
	for part in client_hashes:gmatch("[^:]+") do
		table.insert(parts, part)
	end
	return {
		osupath_md5 = parts[1] or "",
		adapters_str = parts[2] or "",
		adapters_md5 = parts[3] or "",
		uninstall_md5 = parts[4] or "",
		disk_signature_md5 = parts[5] or "",
	}
end

--- Parse the osu version string.
--- Format: "bYYYYMMDDrNstream" e.g. "b20240101r1stable"
---@param version string
---@return {date: string, revision: string, stream: string}|nil
local function parseOsuVersion(version)
	local date_str, rev, stream = version:match("^b(%d%d%d%d%d%d%d%d)(%d?)(.*)$")
	if not date_str then
		return nil
	end
	return {
		date = date_str,
		revision = rev,
		stream = stream,
	}
end

--- Login failure codes.
local LoginFailureReason = {
	AUTHENTICATION_FAILED = -1,
	OLD_CLIENT = -2,
	BANNED = -3,
	ERROR_OCCURRED = -5,
}

--- Result of login parsing.
---@class bancho.auth.LoginResult
---@field ok boolean
---@field data? bancho.auth.LoginData
---@field failure_reason? integer

---@class bancho.auth.LoginHandler
---@operator call: bancho.auth.LoginHandler
local LoginHandler = class()

function LoginHandler:new()
	return self
end

--- Parse a login request body.
--- Expected format:
---   username\n
---   password_md5\n
---   osu_version|utc_offset|display_city|client_hashes|pm_private\n
---
--- @param body string raw request body
--- @return bancho.auth.LoginResult
function LoginHandler.parse(body)
	---@type string[]
	local lines = {}
	for line in body:gmatch("([^\n]+)\n?") do
		if #line > 0 then
			table.insert(lines, line)
		end
	end

	if #lines < 3 then
		return {ok = false, failure_reason = LoginFailureReason.ERROR_OCCURRED}
	end

	local username = lines[1]
	local password_md5 = lines[2]
	local remainder = lines[3]

	if #username == 0 or #password_md5 == 0 then
		return {ok = false, failure_reason = LoginFailureReason.AUTHENTICATION_FAILED}
	end

	---@type string[]
	local parts = {}
	for part in remainder:gmatch("[^|]+") do
		table.insert(parts, part)
	end

	if #parts < 5 then
		return {ok = false, failure_reason = LoginFailureReason.ERROR_OCCURRED}
	end

	local osu_version = parts[1]
	local utc_offset = tonumber(parts[2]) or 0
	local display_city = parts[3] == "1"
	local client_hashes = parts[4]
	local pm_private = parts[5] == "1"

	local parsed_version = parseOsuVersion(osu_version)
	if not parsed_version then
		return {ok = false, failure_reason = LoginFailureReason.ERROR_OCCURRED}
	end

	local hashes = parseClientHashes(client_hashes)

	return {
		ok = true,
		data = {
			username = username,
			password_md5 = password_md5,
			osu_version = parsed_version.date .. parsed_version.revision .. parsed_version.stream,
			utc_offset = utc_offset,
			display_city = display_city,
			client_hashes = hashes,
			pm_private = pm_private,
		},
	}
end

--- Validate login data against restrictions.
---@param login_data bancho.auth.LoginData
---@return boolean
function LoginHandler.validate(self, login_data)
	-- Check for empty adapters (anti-cheat: empty adapters string)
	if login_data.client_hashes.adapters_str == "" then
		return false
	end
	return true
end

return LoginHandler
