--- Account management endpoints.
---
--- Handles in-game registration and difficulty rating redirects.

local IResource = require("web.framework.IResource")
local http_util = require("web.http.util")
local json = require("web.json")
local digest = require("digest")
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

---@param req web.IRequest
---@return {[string]: string}?
---@return string?
local function util_get_fields(req)
	local multipart, err = http_util.get_multipart(req, {read_all = true})
	if not multipart then
		return nil, err or "invalid multipart"
	end

	---@type {[string]: string}
	local fields = {}
	multipart:receive_preamble()

	local headers, receive_err = multipart:receive_headers()
	while headers and receive_err ~= "no parts" do
		local part_data = multipart:receive("*a")
		if part_data then
			local disp = headers:get("Content-Disposition") or ""
			local field_name = disp:match('name="([^"]+)"')
			if field_name then
				fields[field_name] = part_data
			end
		end
		headers, receive_err = multipart:receive_headers()
	end

	return fields
end

---@param res web.IResponse
---@param errors {[string]: string[]}
local function util_send_registration_errors(res, errors)
	res.status = 400

	---@type {[string]: string[]}
	local joined_errors = {}
	for field, field_errors in pairs(errors) do
		if #field_errors > 0 then
			joined_errors[field] = {table.concat(field_errors, "\n")}
		end
	end

	util_send_json(res, {
		form_error = {
			user = joined_errors,
		},
	})
end

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
---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function AccountResource:registerAccount(req, res, ctx)
	if not self.server.config.allow_registration then
		util_send_registration_errors(res, {
			password = {"In-game registration is disabled. Please register on the website."},
		})
		return
	end

	local fields, err = util_get_fields(req)
	if not fields then
		res.status = 400
		res:send(err or "invalid form")
		return
	end

	local username = fields["user[username]"] or ""
	local email = fields["user[user_email]"] or ""
	local password = fields["user[password]"] or ""
	local check = tonumber(fields.check) or 0

	if username == "" or email == "" or password == "" then
		res.status = 400
		res:send("Missing required params")
		return
	end

	---@type {[string]: string[]}
	local errors = {
		username = {},
		user_email = {},
		password = {},
	}

	if #username < 2 or #username > 15 then
		table.insert(errors.username, "Must be 2-15 characters in length.")
	end

	if username:find("_", 1, true) and username:find(" ", 1, true) then
		table.insert(errors.username, 'May contain "_" and " ", but not both.')
	end

	if not email:match("^[^@%s]+@[^@%s]+%.[^@%s]+$") then
		table.insert(errors.user_email, "Invalid email syntax.")
	end

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

	local user_repo = self.server.user_repo
	if #errors.username == 0 and user_repo:findUserByName(username) then
		table.insert(errors.username, "Username already taken by another player.")
	end

	email = email:lower()
	if #errors.user_email == 0 and user_repo:findByEmail(email) then
		table.insert(errors.user_email, "Email already taken by another player.")
	end

	local has_errors = #errors.username > 0 or #errors.user_email > 0 or #errors.password > 0
	if has_errors then
		util_send_registration_errors(res, errors)
		return
	end

	if check == 0 then
		local hasher = BcryptPasswordHasher()
		user_repo:createUser(username, email, hasher:digest(digest.hash("md5", password, true)), "XX")
	end

	res.status = 200
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
