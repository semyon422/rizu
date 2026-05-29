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

	local body, err = req:receive("*a")
	if not body then
		res.status = 400
		res:send(err or "failed to read body")
		return
	end

	local params = http_util.decode_query_string(body)
	local username = params["user[username]"] or ""
	local email = params["user[user_email]"] or ""
	local password = params["user[password]"] or ""
	local check = tonumber(params.check) or 0

	-- Validate required fields
	if not username or not email or not password then
		res.status = 400
		res:send("Missing required params")
		return
	end

	-- Validate username: 2-15 characters, alphanumeric + space/underscore
	if #username < 2 or #username > 15 then
		util_send_json(res, {
			form_error = {
				user = {
					username = {"Must be 2-15 characters in length."},
				},
			},
		})
		return
	end

	if username:find("_") and username:find(" ") then
		util_send_json(res, {
			form_error = {
				user = {
					username = {'May contain "_" and " ", but not both.'},
				},
			},
		})
		return
	end

	-- Validate email format (basic check)
	if not email:match("^[^@%s]+@[^@%s]+%.[^@%s]+$") then
		util_send_json(res, {
			form_error = {
				user = {
					["user_email"] = {"Invalid email syntax."},
				},
			},
		})
		return
	end

	-- Validate password: 8-32 characters, more than 3 unique characters
	if #password < 8 or #password > 32 then
		util_send_json(res, {
			form_error = {
				user = {
					password = {"Must be 8-32 characters in length."},
				},
			},
		})
		return
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
		util_send_json(res, {
			form_error = {
				user = {
					password = {"Must have more than 3 unique characters."},
				},
			},
		})
		return
	end

	-- Check if username/email already taken
	if self.server.user_repo then
		if self.server.user_repo:findUserByName(username) then
			util_send_json(res, {
				form_error = {
					user = {
						username = {"Username already taken by another player."},
					},
				},
			})
			return
		end

		if self.server.user_repo:findByEmail(email) then
			util_send_json(res, {
				form_error = {
					user = {
						["user_email"] = {"Email already taken by another player."},
					},
				},
			})
			return
		end
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

				print(string.format("User %s (%d) registered!", username, user.id))
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
