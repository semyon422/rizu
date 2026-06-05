--- Account management endpoints.
---
--- Handles in-game registration and difficulty rating redirects.

local IResource = require("web.framework.IResource")
local http_util = require("web.http.util")
local json = require("web.json")
local BcryptPasswordHasher = require("sea.access.BcryptPasswordHasher")

local class = require("class")

--- Helper to send JSON response.
---@param res web.IResponse
---@param data any
local function util_send_json(res, data)
	res.headers:set("Content-Type", "application/json")
	res:send(json.encode(data))
end

---@class bancho.http.AccountResource: web.IResource
---@operator call: bancho.http.AccountResource
---@field server bancho.server.BanchoServer
local AccountResource = IResource + {}

AccountResource.routes = {
	-- In-game registration
	{"/users", {
		POST = "registerAccount",
	}},

	-- Difficulty rating redirect
	{"/difficulty-rating", {
		POST = "difficultyRating",
	}},
}

--- Domains that serve account endpoints.
AccountResource.domains = {"osu.*"}

---@param server bancho.server.BanchoServer
function AccountResource:new(server)
	self.server = server
end

--- POST /users
--- In-game account registration.
--- Validates username, email, password and creates user + stats rows.
--- Client sends multipart form data.
---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function AccountResource:registerAccount(req, res, ctx)
	if not self.server.config.allow_registration then
		res.status = 400
		util_send_json(res, {
			form_error = {
				user = {
					password = {"In-game registration is disabled. Please register on the website."},
				},
			},
		})
		return
	end

	-- Parse multipart form data
	local multipart, err = http_util.get_multipart(req, {read_all = true})
	if not multipart then
		res.status = 400
		res:send(err or "invalid multipart")
		return
	end

	-- Extract form fields from multipart
	local fields = {}
	multipart:receive_preamble()
	local headers, err = multipart:receive()
	while headers and err ~= "no parts" do
		local ExtendedSocket = require("web.socket.ExtendedSocket")
		local part_data = ExtendedSocket(multipart.bsoc):receive("*a")
		if part_data then
			local disp = headers:get("Content-Disposition") or ""
			local field_name = disp:match('name="([^"]+)"')
			if field_name then
				fields[field_name] = part_data
			end
		end
		headers, err = multipart:receive()
	end

	local username = fields["user[username]"] or ""
	local email = fields["user[user_email]"] or ""
	local password = fields["user[password]"] or ""
	local check = tonumber(fields.check) or 0

	-- Validate required fields
	if not username or not email or not password then
		res.status = 400
		res:send("Missing required params")
		return
	end

	-- Collect all errors (matches bancho.py approach)
	---@type {[string]: string[]}
	local errors = {
		username = {},
		user_email = {},
		password = {},
	}

	-- Validate username: 2-15 characters, alphanumeric + space/underscore
	if #username < 2 or #username > 15 then
		table.insert(errors.username, "Must be 2-15 characters in length.")
	end

	if username:find("_") and username:find(" ") then
		table.insert(errors.username, 'May contain "_" and " ", but not both.')
	end

	-- Validate email format (basic check)
	if not email:match("^[^@%s]+@[^@%s]+%.[^@%s]+$") then
		table.insert(errors.user_email, "Invalid email syntax.")
	end

	-- Validate password: 8-32 characters, more than 3 unique characters
	if #password < 8 or #password > 32 then
		table.insert(errors.password, "Must be 8-32 characters in length.")
	end

	local unique_chars = {}
	local unique_count = 0
	for i = 1, #password do
		local ch = password:sub(i, i)
		if not unique_chars[ch] then
			unique_chars[ch] = true
			unique_count = unique_count + 1
		end
	end
	if unique_count <= 3 then
		table.insert(errors.password, "Must have more than 3 unique characters.")
	end

	-- Check if username/email already taken (only if no format errors for that field)
	if self.server.user_repo then
		if #errors.username == 0 and self.server.user_repo:findUserByName(username) then
			table.insert(errors.username, "Username already taken by another player.")
		end

		if #errors.user_email == 0 and self.server.user_repo:findByEmail(email) then
			table.insert(errors.user_email, "Email already taken by another player.")
		end
	end

	-- Send all errors at once (matches bancho.py format)
	local has_errors = #errors.username > 0 or #errors.user_email > 0 or #errors.password > 0
	if has_errors then
		-- Join errors with newlines per field (matches bancho.py)
		local joined_errors = {}
		for field, field_errors in pairs(errors) do
			if #field_errors > 0 then
				joined_errors[field] = {table.concat(field_errors, "\n")}
			end
		end
		res.status = 400
		util_send_json(res, {form_error = {user = joined_errors}})
		return
	end

	-- If check == 0, actually create the account
	if check == 0 then
		-- Compute password hash
		-- Client sends plaintext → we compute md5(plaintext) → bcrypt(md5)
		-- This matches bancho.py: client always sends MD5, server stores bcrypt(md5)
		local md5 = require("md5")
		local pw_md5 = md5.sumhexa(password)
		local hasher = BcryptPasswordHasher()
		local pw_bcrypt = hasher:digest(pw_md5)

		-- Get country from IP (TODO: use geolocation service)
		local country = "XX"

		-- Create user
		if self.server.user_repo then
			local user = self.server.user_repo:createUser(
				username,
				email,
				pw_bcrypt,
				country
			)

			if user then
				-- Create stats for all modes
				if self.server.stats_repo then
					self.server.stats_repo:createAllModes(user.id)
				end
			else
				res.status = 500
				res:send("Failed to create user")
				return
			end
		else
			res.status = 500
			res:send("No user repository configured")
			return
		end
	end

	res:send("ok")
end

--- POST /difficulty-rating
--- Redirect to osu.ppy.sh.
---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function AccountResource:difficultyRating(req, res, ctx)
	res.status = 307
	res.headers:set("Location", "https://osu.ppy.sh" .. ctx.parsed_uri.path)
	res:send("")
end

return AccountResource
